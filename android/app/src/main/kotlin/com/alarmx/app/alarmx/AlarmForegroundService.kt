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
import android.os.IBinder
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
 * → this service → `startForeground()` → ongoing ringing notification + default alarm
 * ringtone + repeating vibration.
 *
 * Stopping: the "Stop alarm" notification action sends [ACTION_STOP] back to this
 * service, which stops the ringtone/vibration, leaves the foreground state (removing
 * the notification) and stops itself. No Flutter UI needs to be open. [onDestroy]
 * runs the same cleanup, so every path is leak-free and idempotent.
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

        private const val RINGING_CHANNEL_ID = "alarmx_ringing_channel"
        private const val RINGING_CHANNEL_NAME = "AlarmX Ringing"
        private const val RINGING_NOTIFICATION_ID = 2000

        private const val REQUEST_CODE_CONTENT = 10
        private const val REQUEST_CODE_STOP = 11

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
    }

    @Volatile
    private var isRinging = false
    private var ringtone: Ringtone? = null
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
        acquireWakeLock()
        startRingtone()
        startVibration()
        Log.d(TAG, "Alarm ringing started for id: $alarmId")
    }

    private fun buildRingingNotification(alarmId: Int): Notification {
        val notificationManager =
            getSystemService(NOTIFICATION_SERVICE) as NotificationManager
        ensureRingingChannel(notificationManager)

        val contentIntent = PendingIntent.getActivity(
            this,
            REQUEST_CODE_CONTENT,
            Intent(this, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
                putExtra(EXTRA_ALARM_ID, alarmId)
            },
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        val stopIntent = PendingIntent.getService(
            this,
            REQUEST_CODE_STOP,
            Intent(this, AlarmForegroundService::class.java).apply {
                action = ACTION_STOP
            },
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )

        return NotificationCompat.Builder(this, RINGING_CHANNEL_ID)
            .setSmallIcon(android.R.drawable.ic_lock_idle_alarm)
            .setContentTitle("AlarmX")
            .setContentText("Alarm is ringing")
            .setCategory(NotificationCompat.CATEGORY_ALARM)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setOngoing(true)
            .setAutoCancel(false)
            .setOnlyAlertOnce(true)
            // No notification sound/vibration/defaults: the Ringtone and the
            // Vibrator below are the actual alarm output.
            .setDefaults(0)
            .setContentIntent(contentIntent)
            .addAction(
                android.R.drawable.ic_menu_close_clear_cancel,
                "Stop alarm",
                stopIntent,
            )
            .build()
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
            player.play()
        } catch (e: Exception) {
            Log.w(TAG, "Ringtone playback failed; continuing without sound.", e)
            ringtone = null
        }
    }

    private fun startVibration() {
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
     * paths and [onDestroy].
     */
    private fun stopRinging() {
        isRinging = false
        try {
            ringtone?.takeIf { it.isPlaying }?.stop()
        } catch (e: Exception) {
            Log.w(TAG, "Error stopping ringtone.", e)
        }
        ringtone = null
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
    }
}
