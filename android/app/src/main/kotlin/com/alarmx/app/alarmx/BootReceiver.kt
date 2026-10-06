package com.alarmx.app.alarmx

import android.app.AlarmManager
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Handler
import android.os.Looper
import android.util.Log
import io.flutter.FlutterInjector
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugins.GeneratedPluginRegistrant
import java.util.concurrent.atomic.AtomicBoolean

/**
 * Restores alarm schedules after a device restart.
 *
 * AlarmManager forgets every exact alarm on reboot while the database (and
 * the [AlarmScheduleLedger]) survive, so without this pass enabled alarms
 * would never ring again. On `BOOT_COMPLETED` this receiver spins up a
 * short-lived headless FlutterEngine (no UI, no activity, no permanent
 * service), executes the `reconcileAfterBoot` Dart entrypoint, and destroys
 * the engine once Dart reports `onReconcileComplete`.
 *
 * Scheduling truth stays in Dart: the headless engine serves the same
 * [AlarmSchedulerChannelHandler] as the UI engine, so reconciliation
 * schedules, cancels, and tokenizes through the identical code path. No
 * recurrence math exists on the native side.
 *
 * Safety: the broadcast is extended with `goAsync()` while Dart works, a
 * hard timeout releases everything even if Dart never answers, and every
 * failure path logs and finishes — boot is never blocked and the receiver
 * never crashes. Only `BOOT_COMPLETED` is handled: the database lives in
 * credential-encrypted storage, so reconciling before the user unlocks
 * (`LOCKED_BOOT_COMPLETED`) could not read it. (On devices without a lock
 * screen, `BOOT_COMPLETED` follows boot immediately.)
 */
class BootReceiver : BroadcastReceiver() {

    companion object {
        private const val TAG = "AlarmX"

        /** Dart entrypoint (must match the `vm:entry-point` function). */
        private const val DART_ENTRYPOINT = "reconcileAfterBoot"

        /** Handshake method the Dart pass invokes when it finishes. */
        private const val METHOD_COMPLETE = "onReconcileComplete"

        /**
         * Upper bound for the whole headless pass. A normal pass takes a
         * few seconds; the timeout only guards a wedged engine.
         */
        private const val RECONCILE_TIMEOUT_MS = 20_000L
    }

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != Intent.ACTION_BOOT_COMPLETED) {
            return
        }
        val appContext = context.applicationContext
        val pending = goAsync()
        val finished = AtomicBoolean(false)
        fun finishOnce() {
            if (finished.compareAndSet(false, true)) {
                try {
                    pending.finish()
                } catch (t: Throwable) {
                    Log.w(TAG, "Error finishing boot reconcile.", t)
                }
            }
        }

        var engine: FlutterEngine? = null
        val timeoutHandler = Handler(Looper.getMainLooper())
        val timeoutRunnable = Runnable {
            Log.w(TAG, "Boot reconcile timed out; releasing.")
            destroyQuietly(engine)
            engine = null
            finishOnce()
        }
        timeoutHandler.postDelayed(timeoutRunnable, RECONCILE_TIMEOUT_MS)

        try {
            val loader = FlutterInjector.instance().flutterLoader()
            loader.startInitialization(appContext)
            loader.ensureInitializationComplete(appContext, null)
            val created = FlutterEngine(appContext)
            engine = created
            GeneratedPluginRegistrant.registerWith(created)
            val alarmManager =
                appContext.getSystemService(Context.ALARM_SERVICE) as AlarmManager
            val schedulerHandler = AlarmSchedulerChannelHandler(appContext, alarmManager)
            MethodChannel(
                created.dartExecutor.binaryMessenger,
                AlarmSchedulerChannelHandler.CHANNEL_NAME,
            ).setMethodCallHandler { call, result ->
                if (call.method == METHOD_COMPLETE) {
                    Log.i(TAG, "Boot reconcile complete: ${call.arguments}")
                    result.success(null)
                    timeoutHandler.removeCallbacks(timeoutRunnable)
                    destroyQuietly(created)
                    engine = null
                    finishOnce()
                } else {
                    schedulerHandler.handle(call, result)
                }
            }
            val entrypoint = DartExecutor.DartEntrypoint(
                loader.findAppBundlePath(),
                DART_ENTRYPOINT,
            )
            created.dartExecutor.executeDartEntrypoint(entrypoint)
        } catch (t: Throwable) {
            Log.e(TAG, "Boot reconcile failed to start.", t)
            timeoutHandler.removeCallbacks(timeoutRunnable)
            destroyQuietly(engine)
            engine = null
            finishOnce()
        }
    }

    private fun destroyQuietly(engine: FlutterEngine?) {
        if (engine == null) {
            return
        }
        try {
            engine.destroy()
        } catch (t: Throwable) {
            Log.w(TAG, "Error destroying headless engine.", t)
        }
    }
}
