// Application-layer bridge between the Phase 3 UI and the alarm engine.
//
// Flow (no exceptions to this rule):
//   widgets -> AlarmController -> AlarmRepository + AlarmSchedulingCoordinator
//
// The controller owns the UI-facing operation flows (create/update/toggle/
// delete) and translates engine outcomes into [AlarmUiResult] message keys
// that widgets resolve through `AppStrings`. It never touches the native
// scheduler, the calculator, the ledger, or raw channels: all scheduling
// goes through the coordinator, exactly like every previous phase.
//
// Error philosophy: controller methods never throw for domain/engine
// failures. A row that was persisted but could not be scheduled is
// reported honestly (`persisted: true`, `ok: false`) with a message key
// explaining the gap; only then can the UI avoid claiming a schedule that
// does not exist. Unexpected engine details go to `debugPrint`, never to
// user-visible strings.

import 'package:flutter/foundation.dart' show debugPrint;

import '../database/database.dart';
import '../repositories/alarm_repository.dart';
import '../scheduling/alarm_schedule_result.dart';
import '../scheduling/alarm_scheduling_coordinator.dart';

/// UI-facing outcome of an [AlarmController] operation.
class AlarmUiResult {
  const AlarmUiResult({
    required this.ok,
    required this.persisted,
    required this.messageKey,
  });

  /// True when the desired end state was fully reached (row persisted AND
  /// the OS schedule matches the desired state).
  final bool ok;

  /// True when the database row was written (or, for delete, removed).
  /// False only when persistence itself failed or the row was missing.
  final bool persisted;

  /// [AppStrings] message key the UI shows to the user.
  final String messageKey;
}

/// UI entry point for alarm operations; see the file docs.
class AlarmController {
  const AlarmController({
    required AlarmRepository repository,
    required AlarmSchedulingCoordinator coordinator,
  })  : _repository = repository,
        _coordinator = coordinator;

  final AlarmRepository _repository;
  final AlarmSchedulingCoordinator _coordinator;

  /// Reactive stream of all alarms for the Home screen.
  Stream<List<Alarm>> watchAlarms() => _repository.watchAlarms();

  /// Loads one alarm for the edit screen (`null` when missing).
  ///
  /// Database errors propagate to the caller (the edit screen shows its
  /// load-error state); "not found" is a normal `null`, not an error.
  Future<Alarm?> getAlarmById(int id) => _repository.getAlarmById(id);

  /// Creates an alarm row, then schedules it through the coordinator.
  ///
  /// Scheduling is always attempted (the coordinator handles the disabled
  /// case by clearing strays and reporting [AlarmDisabled], which is the
  /// desired end state for a disabled alarm). Never throws.
  Future<AlarmUiResult> createAlarm(AlarmsCompanion entry) async {
    final int id;
    try {
      id = await _repository.createAlarm(entry);
    } catch (e) {
      debugPrint('AlarmController.createAlarm: database write failed: $e');
      return const AlarmUiResult(
        ok: false,
        persisted: false,
        messageKey: 'msgCreateFailed',
      );
    }
    final AlarmScheduleResult result =
        await _coordinator.scheduleAlarm(id);
    return _scheduledOutcome(
      result,
      scheduledKey: 'msgAlarmSaved',
      context: 'createAlarm($id)',
    );
  }

  /// Replaces an alarm row, then reschedules it through the coordinator.
  ///
  /// The coordinator cancels any previous native schedule for the id
  /// before scheduling the recomputed trigger, so edits never leave a
  /// stale PendingIntent behind. Never throws.
  Future<AlarmUiResult> updateAlarm(Alarm row) async {
    final bool updated;
    try {
      updated = await _repository.updateAlarm(row);
    } catch (e) {
      debugPrint('AlarmController.updateAlarm: database write failed: $e');
      return const AlarmUiResult(
        ok: false,
        persisted: false,
        messageKey: 'msgUpdateFailed',
      );
    }
    if (!updated) {
      return const AlarmUiResult(
        ok: false,
        persisted: false,
        messageKey: 'msgAlarmMissing',
      );
    }
    final AlarmScheduleResult result =
        await _coordinator.rescheduleAlarm(row.id);
    return _scheduledOutcome(
      result,
      scheduledKey: 'msgAlarmUpdated',
      context: 'updateAlarm(${row.id})',
    );
  }

  /// Enables or disables an alarm.
  ///
  /// Enabling persists the flag, then schedules through the coordinator;
  /// disabling persists the flag, then cancels through the coordinator.
  /// The flag and the schedule are stepped separately (rather than via
  /// `enableAlarm`/`disableAlarm`) so a flag-write failure and a
  /// schedule failure report different `persisted` values honestly.
  /// Scheduling itself still goes through the coordinator only. Never
  /// throws. Unknown ids are a successful no-op when disabling (matching
  /// coordinator idempotency) and `msgAlarmMissing` when enabling.
  Future<AlarmUiResult> setEnabled(int id, bool enabled) async {
    final Alarm? existing = await _safeGet(id, 'setEnabled');
    if (existing == null) {
      // Disabled-missing is a no-op success only when nothing needs
      // doing; enabling-missing can never proceed.
      if (!enabled) {
        try {
          await _coordinator.cancelAlarm(id);
        } catch (e) {
          debugPrint('AlarmController.setEnabled($id, false) failed: $e');
          return const AlarmUiResult(
            ok: false,
            persisted: false,
            messageKey: 'msgToggleFailed',
          );
        }
        return const AlarmUiResult(
          ok: true,
          persisted: true,
          messageKey: 'msgAlarmDisabled',
        );
      }
      return const AlarmUiResult(
        ok: false,
        persisted: false,
        messageKey: 'msgAlarmMissing',
      );
    }
    try {
      await _repository.setAlarmEnabled(id, enabled);
    } catch (e) {
      debugPrint('AlarmController.setEnabled($id, $enabled) failed: $e');
      return const AlarmUiResult(
        ok: false,
        persisted: false,
        messageKey: 'msgToggleFailed',
      );
    }
    if (!enabled) {
      try {
        await _coordinator.cancelAlarm(id);
      } catch (e) {
        debugPrint('AlarmController.setEnabled($id, false) failed: $e');
        return const AlarmUiResult(
          ok: false,
          persisted: true,
          messageKey: 'msgScheduleFailed',
        );
      }
      return const AlarmUiResult(
        ok: true,
        persisted: true,
        messageKey: 'msgAlarmDisabled',
      );
    }
    final AlarmScheduleResult result =
        await _coordinator.scheduleAlarm(id);
    return _scheduledOutcome(
      result,
      scheduledKey: 'msgAlarmEnabled',
      context: 'setEnabled($id, true)',
    );
  }

  /// Cancels the native schedule, then deletes the database row.
  ///
  /// Order matters: when cancellation fails the row is kept and the
  /// failure is reported, so the UI never pretends a fully successful
  /// delete while a native schedule may still exist. Missions attached to
  /// the alarm are removed by the schema's FK cascade, not by manual
  /// deletes here. Never throws.
  Future<AlarmUiResult> deleteAlarm(int id) async {
    try {
      await _coordinator.cancelAlarm(id);
    } catch (e) {
      debugPrint('AlarmController.deleteAlarm($id): cancel failed: $e');
      return const AlarmUiResult(
        ok: false,
        persisted: false,
        messageKey: 'msgDeleteFailed',
      );
    }
    final bool deleted;
    try {
      deleted = await _repository.deleteAlarm(id);
    } catch (e) {
      debugPrint('AlarmController.deleteAlarm($id): delete failed: $e');
      return const AlarmUiResult(
        ok: false,
        persisted: false,
        messageKey: 'msgDeleteFailed',
      );
    }
    if (!deleted) {
      return const AlarmUiResult(
        ok: false,
        persisted: false,
        messageKey: 'msgAlarmMissing',
      );
    }
    return const AlarmUiResult(
      ok: true,
      persisted: true,
      messageKey: 'msgAlarmDeleted',
    );
  }

  /// Maps a schedule-family outcome to a UI result. The row was already
  /// persisted by the caller, so every branch reports `persisted: true`.
  AlarmUiResult _scheduledOutcome(
    AlarmScheduleResult result, {
    required String scheduledKey,
    required String context,
  }) {
    switch (result) {
      case AlarmScheduled(:final triggerAt):
        debugPrint('AlarmController.$context: scheduled for $triggerAt');
        return AlarmUiResult(
          ok: true,
          persisted: true,
          messageKey: scheduledKey,
        );
      case AlarmDisabled():
        // Desired end state for a disabled alarm: nothing scheduled.
        return AlarmUiResult(
          ok: true,
          persisted: true,
          messageKey: scheduledKey,
        );
      case AlarmNotSchedulable(:final reason):
        debugPrint('AlarmController.$context: not schedulable: $reason');
        return const AlarmUiResult(
          ok: false,
          persisted: true,
          messageKey: 'msgNotSchedulable',
        );
      case AlarmPermissionMissing():
        debugPrint('AlarmController.$context: exact-alarm permission missing');
        return const AlarmUiResult(
          ok: false,
          persisted: true,
          messageKey: 'msgNoPermission',
        );
      case AlarmScheduleFailed(:final error):
        debugPrint('AlarmController.$context: scheduling failed: $error');
        // The row is persisted but no schedule exists; the message must
        // say exactly that (the coordinator already rolled its native
        // state back, so no leaked schedule is claimed).
        return const AlarmUiResult(
          ok: false,
          persisted: true,
          messageKey: 'msgScheduleFailed',
        );
    }
  }

  /// Loads [id], returning null both when missing and when the read
  /// itself fails (both mean "cannot proceed"; the failure is logged).
  Future<Alarm?> _safeGet(int id, String context) async {
    try {
      return await _repository.getAlarmById(id);
    } catch (e) {
      debugPrint('AlarmController.$context($id): read failed: $e');
      return null;
    }
  }
}
