// Production bootstrap: database + reconciliation wiring without UI.
//
// [runProductionReconciliation] opens the production database file, runs one
// [AlarmSchedulingCoordinator.reconcileSchedules] pass against the live
// native scheduler, closes the database, and returns the report. It is used
// by normal app launch (`main`) and — via the headless entrypoint — by
// system lifecycle receivers, so every trigger reconciles through the exact
// same objects. It opens no UI and owns no global state; each call uses a
// short-lived database connection that is always closed.

import '../alarms/native_alarm_scheduler_impl.dart';
import '../database/database.dart';
import '../repositories/alarm_repository.dart';
import '../scheduling/alarm_schedule_result.dart';
import '../scheduling/alarm_scheduling_coordinator.dart';

/// Runs one production reconciliation pass; see the file docs.
///
/// [now] defaults to the current local time and exists so tests can pin
/// time deterministically. Throws only on catastrophic failure (e.g. the
/// database cannot be opened); per-alarm problems are inside the returned
/// report. Callers decide what a throw means: app launch must continue to
/// the UI, the headless entrypoint must report the error to native.
Future<ReconciliationReport> runProductionReconciliation({
  DateTime? now,
}) async {
  final AppDatabase db = AppDatabase();
  try {
    final AlarmSchedulingCoordinator coordinator = AlarmSchedulingCoordinator(
      repository: DriftAlarmRepository(db.alarmDao),
      scheduler: const NativeAlarmSchedulerImpl(),
    );
    return await coordinator.reconcileSchedules(now: now);
  } finally {
    try {
      await db.close();
    } catch (_) {
      // Cleanup failure must not mask the pass outcome.
    }
  }
}
