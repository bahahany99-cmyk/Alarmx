package com.alarmx.app.alarmx

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Hosts the Flutter engine and wires up the `MethodChannel` that the Dart
 * side uses to schedule and cancel native Android alarms.
 *
 * Channel name: `"com.alarmx.app.alarmx/alarm_scheduler"`
 * Methods:
 *   - `scheduleExactAlarm`  args: `{ "alarmId": Int, "triggerAtMillis": Long }`
 *   - `cancelAlarm`         args: `{ "alarmId": Int }`
 *   - `canScheduleExactAlarms`  args: `{}`
 */
class MainActivity : FlutterActivity() {

    companion object {
        private const val CHANNEL_NAME = "com.alarmx.app.alarmx/alarm_scheduler"
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        val alarmManager =
            getSystemService(Context.ALARM_SERVICE) as AlarmManager

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL_NAME)
            .setMethodCallHandler { call, result ->
                try {
                    when (call.method) {
                        "scheduleExactAlarm" -> {
                            val alarmId = call.argument<Int>("alarmId")
                            val triggerAtMillis = call.argument<Number>("triggerAtMillis")?.toLong()
                            if (alarmId == null || triggerAtMillis == null) {
                                result.error(
                                    "INVALID_ARGS",
                                    "scheduleExactAlarm requires alarmId (Int) and triggerAtMillis (Long).",
                                    null,
                                )
                                return@setMethodCallHandler
                            }
                            scheduleExact(alarmManager, alarmId, triggerAtMillis)
                            result.success(null)
                        }

                        "cancelAlarm" -> {
                            val alarmId = call.argument<Int>("alarmId")
                            if (alarmId == null) {
                                result.error(
                                    "INVALID_ARGS",
                                    "cancelAlarm requires alarmId (Int).",
                                    null,
                                )
                                return@setMethodCallHandler
                            }
                            cancelExact(alarmManager, alarmId)
                            result.success(null)
                        }

                        "canScheduleExactAlarms" -> {
                            val can = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                                alarmManager.canScheduleExactAlarms()
                            } else {
                                true
                            }
                            result.success(can)
                        }

                        else -> result.notImplemented()
                    }
                } catch (t: Throwable) {
                    result.error("NATIVE_ERROR", t.message, null)
                }
            }
    }

    /**
     * Schedules a one-shot exact alarm. The PendingIntent's request code is
     * the alarmId itself so different alarms never collide; this also lets
     * [cancelExact] find the right PendingIntent to cancel.
     */
    private fun scheduleExact(
        alarmManager: AlarmManager,
        alarmId: Int,
        triggerAtMillis: Long,
    ) {
        val pendingIntent = buildAlarmPendingIntent(alarmId)
        alarmManager.setExactAndAllowWhileIdle(
            AlarmManager.RTC_WAKEUP,
            triggerAtMillis,
            pendingIntent,
        )
    }

    /**
     * Cancels the alarm previously scheduled for [alarmId]. The PendingIntent
     * built here must be equivalent to the one used in [scheduleExact] (same
     * request code + same intent component/action/extras); we reuse the
     * single helper to guarantee that.
     *
     * If the alarm already fired and [AlarmForegroundService] is ringing, the
     * service is stopped as well so "cancel" reliably silences the alarm. This
     * is a no-op when the service is not running.
     */
    private fun cancelExact(alarmManager: AlarmManager, alarmId: Int) {
        alarmManager.cancel(buildAlarmPendingIntent(alarmId))
        try {
            stopService(Intent(this, AlarmForegroundService::class.java))
        } catch (t: Throwable) {
            Log.w("AlarmX", "Could not stop ringing service during cancel.", t)
        }
    }

    /**
     * Builds the PendingIntent that AlarmManager uses to fire [AlarmReceiver]
     * for the given alarm. Used by both schedule and cancel so the two
     * PendingIntents are equivalent (a precondition for cancel to work).
     *
     * `FLAG_IMMUTABLE` is required on API 31+ and is safe here because the
     * PendingIntent does not carry a mutable extra payload.
     */
    private fun buildAlarmPendingIntent(alarmId: Int): PendingIntent {
        val intent = Intent(this, AlarmReceiver::class.java).apply {
            action = "com.alarmx.app.alarmx.ALARM_FIRE"
            putExtra(AlarmReceiver.EXTRA_ALARM_ID, alarmId)
        }
        return PendingIntent.getBroadcast(
            this,
            alarmId,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }
}
