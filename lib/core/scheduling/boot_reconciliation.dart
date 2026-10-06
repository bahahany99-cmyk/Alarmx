// Headless entry point for BOOT_COMPLETED schedule reconciliation.
//
// `BootReceiver` (native, no UI, no activity) spins up a short-lived
// headless FlutterEngine and executes [reconcileAfterBoot], which opens the
// same Drift database file the UI uses, runs the existing coordinator
// reconciliation, and reports completion back over the shared scheduler
// channel (`onReconcileComplete`). Native destroys the engine afterwards.
//
// Scheduling truth stays in Dart: this file contains no recurrence math —
// it only wires database + coordinator + the existing channel scheduler,
// reusing the exact objects the UI path uses. In release builds the
// function survives tree-shaking via `vm:entry-point`; its name must match
// `BootReceiver`'s `DART_ENTRYPOINT`.

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../alarms/native_alarm_scheduler_impl.dart';
import '../database/database.dart';
import '../repositories/alarm_repository.dart';
import 'alarm_schedule_result.dart';
import 'alarm_scheduling_coordinator.dart';

/// Shared scheduler channel (must match `AlarmSchedulerChannelHandler`).
const MethodChannel _reconcileChannel =
    MethodChannel('com.alarmx.app.alarmx/alarm_scheduler');

/// Reconciles stored alarms with the OS after boot; see the file docs.
///
/// Always attempts the `onReconcileComplete` handshake, even on failure, so
/// native can release the engine. `ok` is true when the pass completed
/// (per-alarm problems are inside the report counters); otherwise `error`
/// names the catastrophic failure (e.g. database unusable).
@pragma('vm:entry-point')
Future<void> reconcileAfterBoot() async {
  WidgetsFlutterBinding.ensureInitialized();
  final Map<String, Object?> payload = <String, Object?>{'ok': false};
  try {
    final AppDatabase db = AppDatabase();
    try {
      final AlarmSchedulingCoordinator coordinator = AlarmSchedulingCoordinator(
        repository: DriftAlarmRepository(db.alarmDao),
        scheduler: const NativeAlarmSchedulerImpl(),
      );
      final ReconciliationReport report =
          await coordinator.reconcileSchedules();
      payload['ok'] = true;
      payload.addAll(report.toMap());
    } finally {
      try {
        await db.close();
      } catch (_) {
        // Cleanup failure must not mask a completed pass.
      }
    }
  } catch (e) {
    payload['error'] = e.toString();
  }
  try {
    await _reconcileChannel.invokeMethod<void>('onReconcileComplete', payload);
  } catch (_) {
    // Native side already gone (timeout); nothing left to report to.
  }
}
