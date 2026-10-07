package com.alarmx.app.alarmx

import android.app.Activity
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.graphics.Color
import android.os.Build
import android.os.Bundle
import android.util.Log
import android.util.TypedValue
import android.view.Gravity
import android.view.WindowManager
import android.widget.Button
import android.widget.LinearLayout
import android.widget.TextView
import androidx.core.content.ContextCompat
import java.time.Instant
import java.time.ZoneId
import java.time.format.DateTimeFormatter

/**
 * Full-screen ringing surface, launched by the ringing notification's
 * full-screen intent when an alarm fires.
 *
 * Presentation and control only: the activity never schedules, calculates,
 * or reschedules anything, never touches audio/vibration state directly,
 * and never starts the ringing service. Sound, vibration, wake lock, and
 * the stop handoff stay owned by [AlarmForegroundService]; Stop here
 * reuses that service's [AlarmForegroundService.ACTION_STOP].
 *
 * Identity comes from the frozen fire extras (`alarm_id`, optional `label`
 * and `trigger_at_millis`) placed on the launch intent by the service. An
 * intent without a valid id, or with a token the [AlarmScheduleLedger] no
 * longer recognizes (stale delivery, recreated after the ring ended),
 * closes the screen instead of showing a wrong alarm.
 *
 * Lock screen: shown over the lock screen with the screen turned on via
 * the supported setters (window flags on API 26); the lock itself is
 * never bypassed. Navigation stays safe by default: Back finishes without
 * touching the ring (the notification Stop action still works), Home
 * merely stops the screen, and returning re-validates before showing.
 */
class FullScreenAlarmActivity : Activity() {

    companion object {
        private const val TAG = "AlarmX"

        /** Launch extra carrying the ringing alarm row id (required). */
        const val EXTRA_ALARM_ID = "alarm_id"

        /** Launch extra carrying the alarm label (optional). */
        const val EXTRA_LABEL = "label"

        /** Launch extra carrying the fired schedule token (optional). */
        const val EXTRA_TRIGGER_AT_MILLIS = "trigger_at_millis"

        /**
         * In-process broadcast the service sends when a ring ends. Carries
         * [EXTRA_ALARM_ID]; never exported, only closes a matching screen.
         */
        const val ACTION_ALARM_STOPPED = "com.alarmx.app.alarmx.ALARM_STOPPED"

        private val TIME_FORMAT = DateTimeFormatter.ofPattern("HH:mm")
    }

    private var alarmId: Int = -1
    private var ringLabel: String? = null
    private var triggerAtMillis: Long? = null

    private var stateView: TextView? = null
    private var timeView: TextView? = null
    private var labelView: TextView? = null
    private var stopReceiver: BroadcastReceiver? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        showWhenLockedAndTurnScreenOn()
        if (!readAndValidateIntent(intent)) {
            finish()
            return
        }
        setContentView(buildUi())
        refreshUi()
        Log.d(TAG, "Alarm screen opened for id: $alarmId")
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        if (!readAndValidateIntent(intent)) {
            finish()
            return
        }
        refreshUi()
        Log.d(TAG, "Alarm screen updated for id: $alarmId")
    }

    override fun onStart() {
        super.onStart()
        // Re-validate on every return: if the ring ended (stop, cancel,
        // rechain) while the screen was away, close instead of showing
        // a stale alarm.
        if (!isCurrentRing()) {
            finish()
            return
        }
        val receiver = object : BroadcastReceiver() {
            override fun onReceive(context: Context, intent: Intent) {
                if (intent.getIntExtra(EXTRA_ALARM_ID, -1) == alarmId) {
                    Log.d(TAG, "Ring ended; closing alarm screen for id: $alarmId.")
                    finish()
                }
            }
        }
        stopReceiver = receiver
        ContextCompat.registerReceiver(
            this,
            receiver,
            IntentFilter(ACTION_ALARM_STOPPED),
            ContextCompat.RECEIVER_NOT_EXPORTED,
        )
    }

    override fun onStop() {
        try {
            stopReceiver?.let { unregisterReceiver(it) }
        } catch (t: Throwable) {
            Log.w(TAG, "Error unregistering stop receiver.", t)
        }
        stopReceiver = null
        super.onStop()
    }

    private fun showWhenLockedAndTurnScreenOn() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(true)
            setTurnScreenOn(true)
        } else {
            // minSdk 26: only the window flags exist there.
            @Suppress("DEPRECATION")
            window.addFlags(
                WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                    WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON,
            )
        }
    }

    /**
     * Reads the launch intent into fields. Returns false (caller finishes)
     * when the id is missing/invalid or the token is stale.
     */
    private fun readAndValidateIntent(intent: Intent?): Boolean {
        val id = intent?.getIntExtra(EXTRA_ALARM_ID, -1) ?: -1
        if (id < 0) {
            Log.w(TAG, "Closing alarm screen: missing/invalid alarm_id extra.")
            return false
        }
        alarmId = id
        ringLabel = intent?.getStringExtra(EXTRA_LABEL)
        triggerAtMillis = if (intent?.hasExtra(EXTRA_TRIGGER_AT_MILLIS) == true) {
            intent.getLongExtra(EXTRA_TRIGGER_AT_MILLIS, -1L).takeIf { it >= 0 }
        } else {
            null
        }
        if (!isCurrentRing()) {
            Log.w(TAG, "Closing stale alarm screen for id: $alarmId.")
            return false
        }
        return true
    }

    /**
     * True when this screen still describes a live ring: rings carrying a
     * schedule token must still match the ledger; legacy test rings carry
     * no token and are shown as-is.
     */
    private fun isCurrentRing(): Boolean {
        if (alarmId < 0) {
            return false
        }
        val token = triggerAtMillis
        if (token != null &&
            !AlarmScheduleLedger.isCurrentSchedule(this, alarmId, token)
        ) {
            return false
        }
        return true
    }

    private fun buildUi(): LinearLayout {
        val padding = (24 * resources.displayMetrics.density).toInt()
        return LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER
            setPadding(padding, padding, padding, padding)
            setBackgroundColor(Color.BLACK)
            stateView = TextView(this@FullScreenAlarmActivity).apply {
                text = "RINGING"
                setTextColor(Color.RED)
                setTextSize(TypedValue.COMPLEX_UNIT_SP, 28f)
                gravity = Gravity.CENTER
            }
            timeView = TextView(this@FullScreenAlarmActivity).apply {
                setTextColor(Color.WHITE)
                setTextSize(TypedValue.COMPLEX_UNIT_SP, 64f)
                gravity = Gravity.CENTER
            }
            labelView = TextView(this@FullScreenAlarmActivity).apply {
                setTextColor(Color.LTGRAY)
                setTextSize(TypedValue.COMPLEX_UNIT_SP, 24f)
                gravity = Gravity.CENTER
            }
            addView(stateView)
            addView(timeView)
            addView(labelView)
            addView(Button(this@FullScreenAlarmActivity).apply {
                text = "Stop"
                setOnClickListener { stopAlarm() }
            })
        }
    }

    private fun refreshUi() {
        timeView?.text = triggerAtMillis?.let { formatTime(it) } ?: "--:--"
        labelView?.text = ringLabel?.takeIf { it.isNotBlank() } ?: "Alarm $alarmId"
    }

    private fun formatTime(triggerAtMillis: Long): String {
        return try {
            java.time.LocalDateTime.ofInstant(
                Instant.ofEpochMilli(triggerAtMillis),
                ZoneId.systemDefault(),
            ).format(TIME_FORMAT)
        } catch (t: Throwable) {
            Log.w(TAG, "Could not format alarm time.", t)
            "--:--"
        }
    }

    /**
     * Stops through the existing service mechanism, then closes. Never
     * touches audio/vibration state directly.
     */
    private fun stopAlarm() {
        try {
            startService(
                Intent(this, AlarmForegroundService::class.java).apply {
                    action = AlarmForegroundService.ACTION_STOP
                },
            )
        } catch (t: Throwable) {
            Log.w(TAG, "Could not send stop to ringing service.", t)
        }
        finish()
    }
}
