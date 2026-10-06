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
 *   - `scheduleExactAlarm`  args: `{ "alarmId": Int, "triggerAtMillis": Long,
 *       plus for persisted alarms "label": String? and "vibrationEnabled": Boolean }`
 *   - `cancelAlarm`         args: `{ "alarmId": Int }`
 *   - `canScheduleExactAlarms`  args: `{}`
 *
 * A schedule call carrying a fire payload (label and/or vibration key
 * present) is a real persisted alarm: its config is frozen into the
 * PendingIntent extras and the schedule is recorded in [AlarmScheduleLedger]
 * so stale deliveries can be dropped on fire. A call with id + trigger only
 * is a legacy test alarm and keeps the exact Phase 1.2 behavior (id extra
 * only, no ledger interaction). Both share the requestCode slot namespace:
 * scheduling either kind for an id replaces whatever was pending for it.
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
        private const val CHANNEL_NAME = "com.alarmx.app.alarmx/alarm_scheduler"

        /**
         * Channel to the running engine, retained so the ringing service can
         * report stops back to Dart. Null before the first engine attaches;
         * calls into a dead engine throw and are caught by the caller.
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

        val channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL_NAME)
        alarmChannel = channel
        channel.setMethodCallHandler { call, result ->
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
                            // Presence of either fire-payload key marks a real
                            // persisted alarm (Dart always sends both together;
                            // accepting either keeps a partial caller on the
                            // verifying path with defaults).
                            val isPersisted = call.hasArgument("label") ||
                                call.hasArgument("vibrationEnabled")
                            val fireLabel = call.argument<String>("label")
                            val fireVibration =
                                call.argument<Boolean>("vibrationEnabled") ?: true
                            scheduleExact(
                                alarmManager,
                                alarmId,
                                triggerAtMillis,
                                fireLabel,
                                fireVibration,
                                isPersisted,
                            )
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
     *
     * When [isPersisted] is true the fire config is frozen into the
     * PendingIntent and the schedule is recorded in [AlarmScheduleLedger]
     * BEFORE the AlarmManager call (see the ledger ordering contract).
     */
    private fun scheduleExact(
        alarmManager: AlarmManager,
        alarmId: Int,
        triggerAtMillis: Long,
        fireLabel: String?,
        fireVibration: Boolean,
        isPersisted: Boolean,
    ) {
        if (isPersisted) {
            AlarmScheduleLedger.putScheduled(this, alarmId, triggerAtMillis)
        }
        val pendingIntent = buildAlarmPendingIntent(
            alarmId,
            triggerAtMillis,
            fireLabel,
            fireVibration,
            isPersisted,
        )
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
     * single helper to guarantee that. (Intent extras do not affect
     * PendingIntent matching, so this id-only form also cancels persisted
     * schedules that carry a fire payload.)
     *
     * If the alarm already fired and [AlarmForegroundService] is ringing, the
     * service is stopped as well so "cancel" reliably silences the alarm. This
     * is a no-op when the service is not running.
     */
    private fun cancelExact(alarmManager: AlarmManager, alarmId: Int) {
        alarmManager.cancel(buildAlarmPendingIntent(alarmId))
        // AFTER the AlarmManager cancel (see the ledger ordering contract);
        // a no-op for legacy test ids the ledger never recorded.
        AlarmScheduleLedger.removeScheduled(this, alarmId)
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
     * extras are frozen when the PendingIntent is created (nothing ever
     * mutates them afterwards). For persisted alarms the fire config is
     * frozen into the extras so the receiver can verify and forward it with
     * no database or engine access; legacy test alarms carry the id only.
     */
    private fun buildAlarmPendingIntent(
        alarmId: Int,
        triggerAtMillis: Long? = null,
        fireLabel: String? = null,
        fireVibration: Boolean = true,
        isPersisted: Boolean = false,
    ): PendingIntent {
        val intent = Intent(this, AlarmReceiver::class.java).apply {
            action = "com.alarmx.app.alarmx.ALARM_FIRE"
            putExtra(AlarmReceiver.EXTRA_ALARM_ID, alarmId)
            if (isPersisted && triggerAtMillis != null) {
                putExtra(AlarmReceiver.EXTRA_TRIGGER_AT_MILLIS, triggerAtMillis)
                if (fireLabel != null) {
                    putExtra(AlarmReceiver.EXTRA_LABEL, fireLabel)
                }
                putExtra(AlarmReceiver.EXTRA_VIBRATION_ENABLED, fireVibration)
            }
        }
        return PendingIntent.getBroadcast(
            this,
            alarmId,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }
}
