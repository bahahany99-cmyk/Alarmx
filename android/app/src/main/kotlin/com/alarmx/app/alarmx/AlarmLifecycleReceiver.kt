package com.alarmx.app.alarmx

import android.app.AlarmManager
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/**
 * Re-runs schedule reconciliation when system state that native alarms
 * depend on changes: wall clock, calendar date, timezone, the exact-alarm
 * permission grant, or the app package itself being updated.
 *
 * Every handled event delegates to [HeadlessReconcileRunner], which
 * executes the existing Dart reconciliation pass in a short-lived headless
 * engine. This receiver contains no scheduling logic: it only identifies
 * the event (logged by the runner) and triggers the pass. `BOOT_COMPLETED`
 * intentionally stays on [BootReceiver], which shares the same runner.
 *
 * Manifest notes: all five actions are system-originated, so the component
 * is exported; the worst case of a spoofed delivery is one extra
 * idempotent reconcile pass. The exact-alarm action constant is inlined at
 * compile time and simply never fires below API 31. No permission is
 * required to receive any of these actions.
 */
class AlarmLifecycleReceiver : BroadcastReceiver() {

    companion object {
        private val HANDLED_ACTIONS = setOf(
            Intent.ACTION_TIME_CHANGED,
            Intent.ACTION_DATE_CHANGED,
            Intent.ACTION_TIMEZONE_CHANGED,
            AlarmManager.ACTION_SCHEDULE_EXACT_ALARM_PERMISSION_STATE_CHANGED,
            Intent.ACTION_MY_PACKAGE_REPLACED,
        )
    }

    override fun onReceive(context: Context, intent: Intent) {
        val action = intent.action
        if (action == null || action !in HANDLED_ACTIONS) {
            return
        }
        HeadlessReconcileRunner.run(context.applicationContext, action, goAsync())
    }
}
