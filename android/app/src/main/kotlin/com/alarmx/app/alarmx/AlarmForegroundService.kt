package com.alarmx.app.alarmx

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Intent
import android.media.AudioAttributes
import android.media.Ringtone
import android.media.RingtoneManager
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.PowerManager
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import android.util.Log
import androidx.core.app.NotificationCompat

/**
 * Foreground service that rings a fired alarm.
 *
 * Pipeline: `AlarmManager` → [AlarmReceiver] → (`ContextCompat.startForegroundService`)
 * → this service → `startForeground()` → ongoing ringing notification (with a
 * full-screen intent opening the Flutter mission screen via [MainActivity]) +
 * default alarm ringtone (looped until stopped: native looping on API 28+, a
 * completion watcher below) + repeating vibration. On Android 14+ the
 * full-screen launch is attached only when the full-screen-intent permission
 * is granted; otherwise the same high-priority notification still posts and
 * tapping it opens the mission screen.
 *
 * Stopping: the Flutter mission screen stops the ring through the
 * `stopRingingAlarm` channel method, which sends [ACTION_STOP] back to this
 * service; the service stops the ringtone/vibration, leaves the foreground
 * state (removing the notification) and stops itself. There is deliberately
 * no notification stop action: it would dismiss the ring without solving the
 * required missions. Tapping the notification opens the mission screen
 * instead. [onDestroy] runs the same cleanup, so every path is leak-free
 * and idempotent.
 *
 * Fire config: a start may carry [EXTRA_LABEL] (shown in the notification,
 * default text otherwise) and [EXTRA_VIBRATION_ENABLED] (default true).
 * Starts without them — every legacy test alarm — behave exactly as before.
 * A persisted start additionally carries [EXTRA_TRIGGER_AT_MILLIS], the
 * schedule token the stop handoff reports back so Dart can complete or
 * chain that exact schedule.
 */
class AlarmForegroundService : Service() {

    companion object {
        private const val TAG = "AlarmX"

        /** Starts ringing for the alarm id carried in [EXTRA_ALARM_ID]. */
        const val ACTION_START = "com.alarmx.app.alarmx.ALARM_START"

        /** Stops ringing (ringtone + vibration + foreground state) idempotently. */
        const val ACTION_STOP = "com.alarmx.app.alarmx.ALARM_STOP"

        /** Intent extra key carrying the alarm row id. */
        const val EXTRA_ALARM_ID = "alarm_id"

        /** Optional start extra carrying the alarm label (null = default text). */
        const val EXTRA_LABEL = "label"

        /** Start extra carrying the vibration flag (default true). */
        const val EXTRA_VIBRATION_ENABLED = "vibration_enabled"

        /**
         * Start extra carrying the fired schedule token (millis). Present on
         * persisted rings only; identifies which schedule just rang for the
         * post-fire stop handoff.
         */
        const val EXTRA_TRIGGER_AT_MILLIS = "trigger_at_millis"

        /**
         * Visible for the Permission Center snapshot reader, which reports
         * whether this channel is still enabled. The value itself is fixed.
         */
        const val RINGING_CHANNEL_ID = "alarmx_ringing_channel"
        private const val RINGING_CHANNEL_NAME = "AlarmX Ringing"
        private const val RINGING_NOTIFICATION_ID = 2000

        private const val REQUEST_CODE_CONTENT = 10

        /**
         * Repeating vibration pattern: start immediately, vibrate 1000ms,
         * pause 500ms, vibrate 1000ms, ... (repeats from index 0).
         */
        private val VIBRATION_PATTERN = longArrayOf(0, 1000, 500, 1000)

        /**
         * Failsafe upper bound for the ringing wake lock (10 minutes). The
         * normal stop paths release it far earlier; the timeout only guards
         * against a leaked lock if the process is killed abnormally.
         */
        private const val WAKE_LOCK_TIMEOUT_MS = 10L * 60L * 1000L

        /**
         * Re-trigger poll interval for API 26-27 (see [startRingtone]): how
         * often the loop watcher checks whether the one-shot ringtone
         * finished while the ring is still active. Short enough to keep the
         * gap between repeats barely noticeable; the watcher is removed the
         * moment [stopRinging] runs, so no callback can outlive the ring.
         */
        private const val LOOP_POLL_INTERVAL_MS = 250L

        /**
         * Id of the alarm currently ringing, or null when the service is
         * idle. Written by [startRinging]/[stopRinging] and read by the
         * scheduler channel's `isRingingAlarm` query, so Dart
         * reconciliation can leave an in-progress ring alone instead of
         * cancelling the native schedule underneath it.
         */
        @Volatile
        var ringingAlarmId: Int? = null
            private set
    }

    @Volatile
    private var isRinging = false
    private var ringAlarmId: Int = -1
    private var ringTriggerAtMillis: Long? = null
    private var ringLabel: String? = null
    private var vibrationEnabled = true
    private var ringtone: Ringtone? = null
    /**
     * Serializes ringtone replay against [stopRinging]: the API 26-27 loop
     * watcher checks state and replays only while holding this lock, and
     * the stop path disarms the watcher and clears the player under the
     * same lock, so a replay can never slip in after (or during) a stop.
     */
    private val ringtoneLock = Any()
    /**
     * Loop watcher for API 26-27 only ([Ringtone.setLooping] needs API 28+).
     * Both are null on newer releases and whenever no ring is active.
     */
    private var loopHandler: Handler? = null
    private var loopWatcher: Runnable? = null
    private var vibrator: Vibrator? = null
    private var wakeLock: PowerManager.WakeLock? = null

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_STOP -> {
                Log.d(TAG, "Stop action received; stopping ringing alarm.")
                stopRinging()
                stopSelf()
                return START_NOT_STICKY
            }
            else -> {
                val alarmId = intent?.getIntExtra(EXTRA_ALARM_ID, -1) ?: -1
                if (alarmId < 0) {
                    Log.w(TAG, "Ignoring start without a valid alarm_id extra.")
                    stopSelf()
                    return START_NOT_STICKY
                }
                if (isRinging) {
                    Log.d(TAG, "Alarm already ringing; ignoring duplicate start for id: $alarmId.")
                    return START_NOT_STICKY
                }
                ringLabel = intent?.getStringExtra(EXTRA_LABEL)
                vibrationEnabled = intent?.getBooleanExtra(EXTRA_VIBRATION_ENABLED, true) ?: true
                ringAlarmId = alarmId
                ringTriggerAtMillis = if (intent?.hasExtra(EXTRA_TRIGGER_AT_MILLIS) == true) {
                    intent.getLongExtra(EXTRA_TRIGGER_AT_MILLIS, -1L).takeIf { it >= 0 }
                } else {
                    null
                }
                startRinging(alarmId)
                return START_NOT_STICKY
            }
        }
    }

    override fun onDestroy() {
        stopRinging()
        super.onDestroy()
    }

    private fun startRinging(alarmId: Int) {
        // The foreground notification must be posted promptly: Android gives a
        // started foreground service only seconds to call startForeground().
        val notification = try {
            buildRingingNotification(alarmId)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to build ringing notification; aborting.", e)
            stopSelf()
            return
        }
        try {
            startForeground(RINGING_NOTIFICATION_ID, notification)
        } catch (se: SecurityException) {
            // Android 13+: POST_NOTIFICATIONS denied means the foreground
            // notification cannot be shown, so this service cannot run. Stop
            // cleanly instead of crashing.
            Log.w(TAG, "startForeground denied (missing POST_NOTIFICATIONS?). Stopping.", se)
            stopSelf()
            return
        }
        // From here the service is safely in the foreground; sound, vibration
        // and the wake lock are each best-effort and independent.
        isRinging = true
        ringingAlarmId = alarmId
        acquireWakeLock()
        startRingtone()
        startVibration()
        Log.d(TAG, "Alarm ringing started for id: $alarmId")
    }

    private fun buildRingingNotification(alarmId: Int): Notification {
        val notificationManager =
            getSystemService(NOTIFICATION_SERVICE) as NotificationManager
        ensureRingingChannel(notificationManager)

        // Both entries cold-boot MainActivity (NEW_TASK + CLEAR_TASK) with
        // the ring identity, so Dart always consumes the launch at startup
        // through the consume-once bridge and boots into the mission screen.
        val contentIntent = PendingIntent.getActivity(
            this,
            REQUEST_CODE_CONTENT,
            ringActivityIntent(alarmId),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        // Full-screen alarm surface: launched by the system from this
        // notification when the alarm fires. Android 14+ gates this on the
        // full-screen-intent permission, and some OEM skins suppress the
        // auto-launch even then; when it is unavailable the ring still
        // posts this high-priority ongoing notification and a tap opens
        // the same mission screen.
        val fullScreenAllowed = canUseFullScreenIntent(notificationManager)
        val fullScreenIntent =
            if (fullScreenAllowed) buildFullScreenPendingIntent(alarmId) else null

        return NotificationCompat.Builder(this, RINGING_CHANNEL_ID)
            .setSmallIcon(android.R.drawable.ic_lock_idle_alarm)
            .setContentTitle("AlarmX")
            .setContentText(ringLabel?.takeIf { it.isNotBlank() } ?: "Alarm is ringing")
            .apply {
                if (fullScreenIntent != null) {
                    setFullScreenIntent(fullScreenIntent, true)
                } else {
                    Log.w(TAG, "Full-screen launch unavailable; ringing behind a tap-to-open notification.")
                }
            }
            .setCategory(NotificationCompat.CATEGORY_ALARM)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setOngoing(true)
            .setAutoCancel(false)
            .setOnlyAlertOnce(true)
            // No notification sound/vibration/defaults: the Ringtone and the
            // Vibrator below are the actual alarm output.
            .setDefaults(0)
            .setContentIntent(contentIntent)
            .build()
    }

    /**
     * Ring intent opening [MainActivity] for this ring, shared by the
     * notification tap target and the full-screen intent. Always cold-boots
     * the activity (NEW_TASK + CLEAR_TASK) so a stale live engine can never
     * sit on Home while the phone rings; Dart consumes the launch at
     * startup and boots into the mission screen. The frozen fire extras
     * travel along so the screen shows the same alarm event the service is
     * ringing; legacy test rings carry the id only.
     */
    private fun ringActivityIntent(alarmId: Int): Intent {
        return Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK
            putExtra(MainActivity.EXTRA_RINGING, true)
            putExtra(MainActivity.EXTRA_ALARM_ID, alarmId)
            ringLabel?.let { putExtra(MainActivity.EXTRA_LABEL, it) }
            ringTriggerAtMillis?.let {
                putExtra(MainActivity.EXTRA_TRIGGER_AT_MILLIS, it)
            }
        }
    }

    /**
     * Builds the full-screen intent for this ring (see [ringActivityIntent]).
     * The requestCode is the alarm id (same identity as the firing
     * PendingIntent; the activity component keeps the two intents distinct).
     */
    private fun buildFullScreenPendingIntent(alarmId: Int): PendingIntent {
        return PendingIntent.getActivity(
            this,
            alarmId,
            ringActivityIntent(alarmId),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }

    /**
     * Whether the system will honor a full-screen intent right now. Below
     * Android 14 (API 34) there is no such permission and the intent is
     * always attempted; on 14+ the check reflects the user's grant state.
     * A failed check fails open: attempting the intent is harmless.
     */
    private fun canUseFullScreenIntent(notificationManager: NotificationManager): Boolean {
        if (Build.VERSION.SDK_INT < 34) {
            return true
        }
        return try {
            notificationManager.canUseFullScreenIntent()
        } catch (e: Exception) {
            Log.w(TAG, "Full-screen permission check failed; attempting full-screen.", e)
            true
        }
    }

    private fun ensureRingingChannel(notificationManager: NotificationManager) {
        if (notificationManager.getNotificationChannel(RINGING_CHANNEL_ID) != null) return
        val channel = NotificationChannel(
            RINGING_CHANNEL_ID,
            RINGING_CHANNEL_NAME,
            NotificationManager.IMPORTANCE_HIGH,
        ).apply {
            description = "Ongoing notification shown while an alarm is ringing."
            // Sound and vibration are driven by the Ringtone/Vibrator, not by
            // the notification channel.
            setSound(null, null)
            enableVibration(false)
            lockscreenVisibility = Notification.VISIBILITY_PUBLIC
        }
        notificationManager.createNotificationChannel(channel)
    }

    private fun startRingtone() {
        try {
            val uri: Uri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_ALARM)
                ?: RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION)
                ?: run {
                    Log.w(TAG, "No default alarm/notification sound URI; ringing without sound.")
                    return
                }
            val player = RingtoneManager.getRingtone(applicationContext, uri)
            if (player == null) {
                Log.w(TAG, "Could not load ringtone for $uri; ringing without sound.")
                return
            }
            player.audioAttributes = AudioAttributes.Builder()
                .setUsage(AudioAttributes.USAGE_ALARM)
                .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                .build()
            ringtone = player
            // A single play() ends when the tone file ends (~10s on tested
            // devices), leaving vibration-only ringing. Loop instead:
            // native looping on API 28+, a completion watcher below.
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                player.isLooping = true
            }
            player.play()
            if (Build.VERSION.SDK_INT < Build.VERSION_CODES.P) {
                startLoopWatcher(player)
            }
        } catch (e: Exception) {
            Log.w(TAG, "Ringtone playback failed; continuing without sound.", e)
            ringtone = null
        }
    }

    /**
     * Manual loop for API 26-27, where [Ringtone.setLooping] does not exist.
     * Re-posts itself every [LOOP_POLL_INTERVAL_MS] while the ring is
     * active, replaying [player] whenever it finished naturally. The
     * state-check-plus-replay-plus-repost runs atomically under
     * [ringtoneLock] (see [stopRinging]), so it can never interleave with
     * the stop: either the tick fully finishes before the stop disarms it
     * (and its repost is removed there) or it sees the cleared state and
     * returns without replaying or reposting, ending the chain.
     */
    private fun startLoopWatcher(player: Ringtone) {
        val handler = Handler(Looper.getMainLooper())
        loopHandler = handler
        val watcher = object : Runnable {
            override fun run() {
                synchronized(ringtoneLock) {
                    if (!isRinging || ringtone !== player) {
                        return
                    }
                    try {
                        if (!player.isPlaying) {
                            player.play()
                        }
                    } catch (e: Exception) {
                        Log.w(TAG, "Ringtone replay failed.", e)
                    }
                    handler.postDelayed(this, LOOP_POLL_INTERVAL_MS)
                }
            }
        }
        loopWatcher = watcher
        handler.postDelayed(watcher, LOOP_POLL_INTERVAL_MS)
    }

    private fun startVibration() {
        if (!vibrationEnabled) {
            Log.d(TAG, "Vibration disabled for this alarm; ringing without vibration.")
            return
        }
        try {
            val vib: Vibrator? = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                getSystemService(VibratorManager::class.java)?.defaultVibrator
            } else {
                @Suppress("DEPRECATION")
                getSystemService(VIBRATOR_SERVICE) as? Vibrator
            }
            if (vib == null || !vib.hasVibrator()) {
                Log.w(TAG, "No vibrator available; ringing without vibration.")
                return
            }
            vibrator = vib
            // minSdk 26, so VibrationEffect is always available here.
            vib.vibrate(VibrationEffect.createWaveform(VIBRATION_PATTERN, 0))
        } catch (e: Exception) {
            Log.w(TAG, "Vibration failed; continuing without vibration.", e)
            vibrator = null
        }
    }

    private fun acquireWakeLock() {
        try {
            val powerManager = getSystemService(POWER_SERVICE) as PowerManager
            val lock = powerManager.newWakeLock(
                PowerManager.PARTIAL_WAKE_LOCK,
                "AlarmX::Ringing",
            )
            // Timeout is a failsafe; normal stop paths release the lock earlier.
            lock.acquire(WAKE_LOCK_TIMEOUT_MS)
            wakeLock = lock
        } catch (e: Exception) {
            Log.w(TAG, "Could not acquire ringing wake lock; continuing without it.", e)
            wakeLock = null
        }
    }

    /**
     * Stops the ringtone, cancels vibration, releases the wake lock and leaves
     * the foreground state (removing the ongoing notification). Idempotent:
     * safe to call multiple times from the Stop action, [stopService]/cancel
     * paths and [onDestroy]. When the call ends an actual ring of a
     * persisted alarm it also fires the one-shot post-fire handoff
     * ([MainActivity.notifyAlarmStopped]); duplicate calls report nothing.
     */
    private fun stopRinging() {
        val wasRinging = isRinging
        val stoppedAlarmId = ringAlarmId
        val stoppedTriggerAtMillis = ringTriggerAtMillis
        isRinging = false
        ringAlarmId = -1
        ringTriggerAtMillis = null
        ringingAlarmId = null
        // First: disarm the API 26-27 loop watcher so no replay can fire
        // after this stop. Removal plus the player stop/clear below run
        // under [ringtoneLock], matching the watcher's atomic
        // check-plus-replay-plus-repost, so the two can never interleave
        // (see [startLoopWatcher]). Idempotent: null-safe on repeat calls.
        synchronized(ringtoneLock) {
            try {
                val handler = loopHandler
                val watcher = loopWatcher
                if (handler != null && watcher != null) {
                    handler.removeCallbacks(watcher)
                }
            } catch (e: Exception) {
                Log.w(TAG, "Error removing ringtone loop watcher.", e)
            }
            loopHandler = null
            loopWatcher = null
            try {
                ringtone?.takeIf { it.isPlaying }?.stop()
            } catch (e: Exception) {
                Log.w(TAG, "Error stopping ringtone.", e)
            }
            ringtone = null
        }
        try {
            vibrator?.cancel()
        } catch (e: Exception) {
            Log.w(TAG, "Error cancelling vibration.", e)
        }
        vibrator = null
        try {
            wakeLock?.let { if (it.isHeld) it.release() }
        } catch (e: Exception) {
            Log.w(TAG, "Error releasing wake lock.", e)
        }
        wakeLock = null
        try {
            // minSdk 26, so STOP_FOREGROUND_REMOVE (API 24+) is always available.
            stopForeground(STOP_FOREGROUND_REMOVE)
        } catch (e: Exception) {
            Log.w(TAG, "Error leaving foreground state.", e)
        }
        if (!wasRinging) {
            return
        }
        // Post-fire handoff, exactly once per completed ring: the identity
        // was cleared above, so duplicate stop calls find wasRinging false.
        // Legacy test rings carry no schedule token and stay silent.
        if (stoppedTriggerAtMillis != null) {
            MainActivity.notifyAlarmStopped(stoppedAlarmId, stoppedTriggerAtMillis)
        }
    }
}
