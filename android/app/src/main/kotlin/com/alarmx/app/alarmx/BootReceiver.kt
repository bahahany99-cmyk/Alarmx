package com.alarmx.app.alarmx

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/**
 * Restores alarm schedules after a device restart.
 *
 * AlarmManager forgets every exact alarm on reboot while the database (and
 * the [AlarmScheduleLedger]) survive, so without this pass enabled alarms
 * would never ring again. On `BOOT_COMPLETED` this receiver delegates to
 * [HeadlessReconcileRunner], which runs the headless Dart reconciliation
 * pass (no UI, no activity, no permanent service).
 *
 * Only `BOOT_COMPLETED` is handled: the database lives in
 * credential-encrypted storage, so reconciling before the user unlocks
 * (`LOCKED_BOOT_COMPLETED`) could not read it. (On devices without a lock
 * screen, `BOOT_COMPLETED` follows boot immediately.)
 */
class BootReceiver : BroadcastReceiver() {

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != Intent.ACTION_BOOT_COMPLETED) {
            return
        }
        HeadlessReconcileRunner.run(
            context.applicationContext,
            Intent.ACTION_BOOT_COMPLETED,
            goAsync(),
        )
    }
}
