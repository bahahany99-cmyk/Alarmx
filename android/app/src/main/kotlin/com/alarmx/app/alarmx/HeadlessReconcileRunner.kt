package com.alarmx.app.alarmx

import android.app.AlarmManager
import android.content.BroadcastReceiver
import android.content.Context
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
 * Runs one headless Dart reconciliation pass for system lifecycle events.
 *
 * Shared by [BootReceiver] (`BOOT_COMPLETED`) and [AlarmLifecycleReceiver]
 * (clock/date/timezone/permission/package events) so every trigger executes
 * the identical engine lifecycle: initialize -> create engine -> register
 * plugins -> serve [AlarmSchedulerChannelHandler] plus the completion
 * handshake -> execute the `reconcileAfterBoot` Dart entrypoint -> destroy
 * the engine once Dart reports `onReconcileComplete`.
 *
 * Scheduling truth stays in Dart; this runner only hosts execution. Safety:
 * the broadcast is extended with the caller's `goAsync()` result while Dart
 * works, a hard timeout releases everything even if Dart never answers, and
 * every failure path logs and finishes — the system is never blocked and
 * the receiver never crashes.
 *
 * Single-flight: at most one pass runs per process. A trigger arriving
 * while a pass is in flight is skipped (not queued): the running pass
 * already reconciles the full alarm set, so skipping is correct and avoids
 * concurrent engines contending on the database. The flag is cleared on
 * every exit path (complete, timeout, start failure).
 */
object HeadlessReconcileRunner {

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

    private val reconcileInFlight = AtomicBoolean(false)

    /**
     * Runs the pass for [reason] (the triggering system action, used for
     * logging), completing [pending] on every exit path. Must be called on
     * the main thread (as `BroadcastReceiver.onReceive` is).
     */
    fun run(
        appContext: Context,
        reason: String,
        pending: BroadcastReceiver.PendingResult,
    ) {
        if (!reconcileInFlight.compareAndSet(false, true)) {
            Log.i(TAG, "Reconcile ($reason) skipped: another pass is running.")
            finishQuietly(pending, reason)
            return
        }
        val finished = AtomicBoolean(false)
        fun finishOnce() {
            if (finished.compareAndSet(false, true)) {
                finishQuietly(pending, reason)
            }
        }

        var engine: FlutterEngine? = null
        val timeoutHandler = Handler(Looper.getMainLooper())
        val timeoutRunnable = Runnable {
            Log.w(TAG, "Reconcile ($reason) timed out; releasing.")
            destroyQuietly(engine)
            engine = null
            reconcileInFlight.set(false)
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
                    Log.i(TAG, "Reconcile ($reason) complete: ${call.arguments}")
                    result.success(null)
                    timeoutHandler.removeCallbacks(timeoutRunnable)
                    destroyQuietly(created)
                    engine = null
                    reconcileInFlight.set(false)
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
            Log.e(TAG, "Reconcile ($reason) failed to start.", t)
            timeoutHandler.removeCallbacks(timeoutRunnable)
            destroyQuietly(engine)
            engine = null
            reconcileInFlight.set(false)
            finishOnce()
        }
    }

    private fun finishQuietly(pending: BroadcastReceiver.PendingResult, reason: String) {
        try {
            pending.finish()
        } catch (t: Throwable) {
            Log.w(TAG, "Error finishing reconcile ($reason).", t)
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
