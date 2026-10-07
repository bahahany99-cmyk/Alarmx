package com.alarmx.app.alarmx

import android.app.AlarmManager
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Bundle
import android.util.Log
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Hosts the Flutter engine and wires up the alarm-scheduler `MethodChannel`.
 *
 * Dart -> native scheduling calls are handled by
 * [AlarmSchedulerChannelHandler] (shared with the headless boot engine, so
 * both paths schedule identically); this activity only retains the channel
 * so the ringing service can report stops back to Dart.
 *
 * Reverse direction (native -> Dart, best-effort): when a persisted alarm
 * stops ringing, [AlarmForegroundService] calls [notifyAlarmStopped], which
 * delivers `onAlarmStopped { "alarmId": Int, "triggerAtMillis": Long }` on
 * this same channel so Dart can chain the next occurrence. Delivery needs a
 * live engine (the channel retained from [configureFlutterEngine]); when the
 * process has none, the stop is simply not reported and ringing is
 * unaffected. The fired trigger travels as a millis token so Dart can reject
 * stale/duplicate deliveries without any native database access.
 *
 * Ring launches (Phase 4): when an alarm fires, the ringing notification's
 * full-screen intent (and its tap target) launches this activity with
 * [EXTRA_RINGING] plus the frozen ring identity ([EXTRA_ALARM_ID], optional
 * [EXTRA_LABEL] and [EXTRA_TRIGGER_AT_MILLIS]). The launch is stashed from
 * the intent and served exactly once to Dart's `getRingingLaunch`
 * ([consumeRingingLaunch]) so the app boots into the Flutter mission
 * screen for that ring instead of Home; every other start boots normally.
 * Ring intents always cold-boot this activity (NEW_TASK + CLEAR_TASK), so a
 * stale live engine can never sit on Home while the phone rings. Ring
 * launches also show over the lock screen with the screen on (never
 * bypassing the lock); normal launches behave exactly as before.
 */
class MainActivity : FlutterActivity() {

    companion object {
        /**
         * Channel to the running engine, retained so the ringing service can
         * report stops back to Dart. Null before the first engine attaches;
         * calls into a dead engine throw and are caught by the caller.
         *
         * Only the UI engine is retained here: the short-lived headless boot
         * engine never rings, so it never needs the stop handoff.
         */
        private var alarmChannel: MethodChannel? = null

        /**
         * Best-effort post-fire handoff: tells Dart that the persisted alarm
         * [alarmId] finished ringing for [triggerAtMillis], so the
         * coordinator can complete or chain it. Fire-and-forget: a missing
         * or dead engine only skips the report (ringing already stopped),
         * never crashes. Stale/duplicate deliveries are rejected Dart-side
         * using the trigger token.
         */
        fun notifyAlarmStopped(alarmId: Int, triggerAtMillis: Long) {
            val channel = alarmChannel
            if (channel == null) {
                Log.d("AlarmX", "No engine channel; skipping post-fire notify for id: $alarmId.")
                return
            }
            try {
                channel.invokeMethod(
                    "onAlarmStopped",
                    mapOf("alarmId" to alarmId, "triggerAtMillis" to triggerAtMillis),
                )
            } catch (t: Throwable) {
                Log.w("AlarmX", "Post-fire notify failed for id: $alarmId.", t)
            }
        }

        /** Launch extra marking a ring launch (Boolean, set only by the ringing service). */
        const val EXTRA_RINGING = "ringing"

        /** Launch extra carrying the ringing alarm row id. */
        const val EXTRA_ALARM_ID = "alarm_id"

        /** Launch extra carrying the alarm label (optional). */
        const val EXTRA_LABEL = "label"

        /** Launch extra carrying the fired schedule token (optional). */
        const val EXTRA_TRIGGER_AT_MILLIS = "trigger_at_millis"

        /**
         * Pending ring launch for Dart's `getRingingLaunch`, in the exact
         * `{alarmId, label?, triggerAtMillis?}` shape. Stashed from the
         * launch intent; null for normal starts.
         */
        private var pendingRingLaunch: Map<String, Any?>? = null

        /**
         * Stashes a ring launch from [intent]. A normal [intent] clears any
         * pending launch only when [clearWhenNormal] is true: [onCreate]
         * passes true (every creation either carries a ring or owns no
         * ring), while [onNewIntent] passes false (a normal re-launch must
         * never drop a ring Flutter has not consumed yet). A ring intent
         * without a valid id is ignored, never stashed.
         */
        fun stashRingingLaunch(intent: Intent?, clearWhenNormal: Boolean) {
            if (intent?.getBooleanExtra(EXTRA_RINGING, false) != true) {
                if (clearWhenNormal) {
                    pendingRingLaunch = null
                }
                return
            }
            val alarmId = intent.getIntExtra(EXTRA_ALARM_ID, -1)
            if (alarmId < 0) {
                Log.w("AlarmX", "Ignoring ring launch without a valid alarm_id extra.")
                return
            }
            val launch = mutableMapOf<String, Any?>("alarmId" to alarmId)
            intent.getStringExtra(EXTRA_LABEL)?.let { launch["label"] = it }
            if (intent.hasExtra(EXTRA_TRIGGER_AT_MILLIS)) {
                val token = intent.getLongExtra(EXTRA_TRIGGER_AT_MILLIS, -1L)
                if (token >= 0) {
                    launch["triggerAtMillis"] = token
                }
            }
            pendingRingLaunch = launch
            Log.d("AlarmX", "Stashed ring launch for id: $alarmId.")
        }

        /**
         * Returns the pending ring launch for Dart, clearing it so each
         * ring is consumed exactly once. Null for normal starts.
         */
        fun consumeRingingLaunch(): Map<String, Any?>? {
            val launch = pendingRingLaunch
            pendingRingLaunch = null
            return launch
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        stashRingingLaunch(intent, clearWhenNormal = true)
        if (intent?.getBooleanExtra(EXTRA_RINGING, false) == true) {
            showWhenLockedAndTurnScreenOn()
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        stashRingingLaunch(intent, clearWhenNormal = false)
    }

    override fun onDestroy() {
        // A destroyed activity owns no ring: clear so a later normal boot
        // can never consume this launch.
        pendingRingLaunch = null
        super.onDestroy()
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

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        val alarmManager =
            getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val schedulerHandler = AlarmSchedulerChannelHandler(this, alarmManager)

        val channel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            AlarmSchedulerChannelHandler.CHANNEL_NAME,
        )
        alarmChannel = channel
        channel.setMethodCallHandler { call, result ->
            schedulerHandler.handle(call, result)
        }
    }
}
