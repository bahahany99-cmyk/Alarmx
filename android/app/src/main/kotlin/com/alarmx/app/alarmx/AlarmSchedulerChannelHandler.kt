package com.alarmx.app.alarmx

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Dart -> native alarm-scheduler calls, shared by the UI engine
 * ([MainActivity]) and the headless boot engine ([BootReceiver]) so both
 * paths schedule, cancel, and tokenize identically.
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
 */
class AlarmSchedulerChannelHandler(
    private val context: Context,
    private val alarmManager: AlarmManager,
) {

    companion object {
        const val CHANNEL_NAME = "com.alarmx.app.alarmx/alarm_scheduler"
    }

    /**
     * Handles one scheduler call, reporting argument problems as
     * `INVALID_ARGS` and unexpected failures as `NATIVE_ERROR`. Unknown
     * methods answer `notImplemented` so hosts can layer their own methods
     * (e.g. the boot completion handshake) around this handler.
     */
    fun handle(call: MethodCall, result: MethodChannel.Result) {
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
                        return@handle
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
                        return@handle
                    }
                    cancelExact(alarmId)
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
        alarmId: Int,
        triggerAtMillis: Long,
        fireLabel: String?,
        fireVibration: Boolean,
        isPersisted: Boolean,
    ) {
        if (isPersisted) {
            AlarmScheduleLedger.putScheduled(context, alarmId, triggerAtMillis)
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
    private fun cancelExact(alarmId: Int) {
        alarmManager.cancel(buildAlarmPendingIntent(alarmId))
        // AFTER the AlarmManager cancel (see the ledger ordering contract);
        // a no-op for legacy test ids the ledger never recorded.
        AlarmScheduleLedger.removeScheduled(context, alarmId)
        try {
            context.stopService(Intent(context, AlarmForegroundService::class.java))
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
        val intent = Intent(context, AlarmReceiver::class.java).apply {
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
            context,
            alarmId,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }
}
