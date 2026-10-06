package com.alarmx.app.alarmx

import android.content.Context

/**
 * Minimal native record of currently-scheduled persisted alarms.
 *
 * Maps each scheduled alarm id to the exact trigger time (epoch millis) of
 * the [android.app.AlarmManager] schedule that is supposed to be live. On
 * fire, [AlarmReceiver] drops any persisted-alarm intent whose trigger does
 * not match the ledger (stale delivery after cancel/reschedule, or a trigger
 * value no schedule ever wrote).
 *
 * This is NOT a database: it stores no alarm configuration, only
 * id -> trigger schedule tokens for alarms [MainActivity] actually
 * scheduled with a fire payload. Legacy test alarms (id only, no payload)
 * never touch the ledger and keep their exact Phase 1.2 behavior.
 *
 * Write ordering contracts (dropping a legitimate alarm is worse than
 * keeping a harmless phantom entry, because entries alone can never ring):
 * - schedule: [putScheduled] BEFORE `setExactAndAllowWhileIdle`, so a crash
 *   in between leaves a phantom (nothing scheduled) rather than a live
 *   schedule the ledger would later drop as stale.
 * - cancel: `AlarmManager.cancel` BEFORE [removeScheduled], so a crash in
 *   between leaves a phantom rather than a live schedule with no ledger
 *   entry (which would drop a legitimate alarm).
 * Stale entries are overwritten by the next schedule of the same id and are
 * harmless on their own: without a live PendingIntent delivery there is
 * nothing to verify, hence nothing to ring.
 *
 * Limitations (current scope): entries do not survive the alarm being fired
 * (delivery keeps the entry until the next schedule/cancel overwrites it)
 * and schedules themselves do not survive reboot; a future boot phase will
 * rebuild schedules (and thereby the ledger) from the database.
 */
object AlarmScheduleLedger {
    private const val PREFS_NAME = "alarmx_schedules"
    private const val KEY_PREFIX = "schedule_"

    /** Records [triggerAtMillis] as the expected trigger for [alarmId]. */
    fun putScheduled(context: Context, alarmId: Int, triggerAtMillis: Long) {
        prefs(context).edit().putLong(key(alarmId), triggerAtMillis).apply()
    }

    /** Forgets any schedule recorded for [alarmId]. */
    fun removeScheduled(context: Context, alarmId: Int) {
        prefs(context).edit().remove(key(alarmId)).apply()
    }

    /**
     * Returns true only when [triggerAtMillis] is the trigger currently
     * recorded for [alarmId]. Unknown ids and mismatched triggers (stale
     * deliveries) return false.
     */
    fun isCurrentSchedule(
        context: Context,
        alarmId: Int,
        triggerAtMillis: Long,
    ): Boolean {
        val prefs = prefs(context)
        if (!prefs.contains(key(alarmId))) return false
        return prefs.getLong(key(alarmId), -1L) == triggerAtMillis
    }

    private fun prefs(context: Context) =
        context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)

    private fun key(alarmId: Int) = "$KEY_PREFIX$alarmId"
}
