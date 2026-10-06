package com.alarmx.app.alarmx

import android.app.AlarmManager
import android.content.Context
import android.util.Log
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
