// Application-layer bridge between the database and the native scheduler.
//
// Pipeline:
//   AlarmRepository -> AlarmSchedule -> NextOccurrenceCalculator
//       -> AlarmSchedulingCoordinator -> NativeAlarmScheduler
//       -> AlarmManager -> AlarmReceiver -> AlarmForegroundService
//
// Responsibilities (and ONLY these):
//   - translate a stored `Alarm` row into an [AlarmSchedule],
//   - ask [NextOccurrenceCalculator] for the next local trigger,
//   - drive [NativeAlarmScheduler] with the alarm's real database id
//     (never random/timestamp/hardcoded ids),
//   - keep the row's `nextTriggerAt` truthful: it holds the trigger currently
//     scheduled with the OS, or null when nothing is scheduled.
//
// Boundaries (deliberate, Phase 2.2 scope):
//   - Only the NEXT occurrence is ever scheduled. No Dart timers keep the
//     alarm alive; recurring re-scheduling after firing happens in
//     [rescheduleAfterFire], driven by the native stop handoff, while
//     boot-time re-scheduling belongs to a later native phase.
//   - No scheduling logic lives in DAOs, entities, widgets, the repository
//     SQL, or MainActivity: repositories persist, the native scheduler talks
//     to Android, this coordinator orchestrates.
//   - `updatedAt` is intentionally left untouched by coordinator writes; row
//     timestamp policy belongs to a future repository-layer pass.
//
// Failure philosophy: scheduling calls never pretend success. The schedule
// family (`scheduleAlarm`, `enableAlarm`, `rescheduleAlarm`,
// `rescheduleAfterFire`) never throws
// for domain/scheduler failures and reports everything via
// [AlarmScheduleResult]. `cancelAlarm`/`disableAlarm` are idempotent
// fire-and-forget state changes (unknown ids are a successful no-op) and
// propagate bridge/database errors to the caller instead.

import 'package:drift/drift.dart';

import '../alarms/alarm_fire_config.dart';
import '../alarms/native_alarm_scheduler.dart';
import '../database/database.dart';
import '../models/models.dart';
import '../repositories/alarm_history_repository.dart';
import '../repositories/alarm_repository.dart';
import 'alarm_schedule.dart';
import 'alarm_schedule_result.dart';
import 'next_occurrence_calculator.dart';
import 'snooze_policy.dart';

/// Orchestrates database state and OS alarm schedules.
class AlarmSchedulingCoordinator {
  const AlarmSchedulingCoordinator({
    required AlarmRepository repository,
    required NativeAlarmScheduler scheduler,
    NextOccurrenceCalculator calculator = const NextOccurrenceCalculator(),
    AlarmHistoryRepository? history,
  })  : _repository = repository,
        _scheduler = scheduler,
        _calculator = calculator,
        _history = history;

  final AlarmRepository _repository;
  final NativeAlarmScheduler _scheduler;
  final NextOccurrenceCalculator _calculator;

  /// Episode history for snooze counting and pending-snooze preservation.
  /// Null (tests, early shells) disables both: the snooze count reads as
  /// zero and reconciliation always recomputes from recurrence.
  final AlarmHistoryRepository? _history;

  /// Schedules the alarm's next occurrence with the OS.
  ///
  /// Flow: load -> skip when disabled/unschedulable (cancelling strays) ->
  /// require exact-alarm permission -> cancel previous native schedule ->
  /// schedule the computed trigger -> persist it to `nextTriggerAt`.
  /// Never throws for domain or scheduler failures; see
  /// [AlarmScheduleResult]. [now] defaults to the current local time and
  /// exists so tests can pin time deterministically.
  Future<AlarmScheduleResult> scheduleAlarm(int id, {DateTime? now}) async {
    final DateTime at = now ?? DateTime.now();
    final Alarm? alarm = await _repository.getAlarmById(id);
    if (alarm == null) {
      return AlarmScheduleFailed(StateError('Alarm $id not found.'));
    }
    if (!alarm.enabled) {
      try {
        await _scheduler.cancelAlarm(alarmId: id);
        await _clearNextTrigger(id);
      } catch (e) {
        return AlarmScheduleFailed(e);
      }
      return const AlarmDisabled();
    }
    final DateTime? trigger = _calculator.nextOccurrence(
      schedule: _toSchedule(alarm),
      now: at,
    );
    if (trigger == null) {
      try {
        await _scheduler.cancelAlarm(alarmId: id);
        await _clearNextTrigger(id);
      } catch (e) {
        return AlarmScheduleFailed(e);
      }
      return AlarmNotSchedulable(_unschedulableReason(alarm));
    }
    final bool allowed;
    try {
      allowed = await _scheduler.canScheduleExactAlarms();
    } catch (e) {
      return AlarmScheduleFailed(e);
    }
    if (!allowed) {
      try {
        await _scheduler.cancelAlarm(alarmId: id);
        await _clearNextTrigger(id);
      } catch (e) {
        return AlarmScheduleFailed(e);
      }
      return const AlarmPermissionMissing();
    }
    try {
      await _scheduler.cancelAlarm(alarmId: id);
    } catch (e) {
      return AlarmScheduleFailed(e);
    }
    try {
      await _scheduler.scheduleExactAlarm(
        alarmId: id,
        triggerAt: trigger,
        fireConfig: AlarmFireConfig(
          label: alarm.label,
          vibrationEnabled: alarm.vibrationEnabled,
        ),
      );
    } catch (e) {
      // Native side is empty (the cancel above succeeded): clear the stored
      // trigger so the database cannot claim a schedule that does not exist.
      await _clearBestEffort(id);
      return AlarmScheduleFailed(e);
    }
    try {
      final bool persisted = await _persistNextTrigger(id, trigger);
      if (!persisted) {
        throw StateError('Alarm $id no longer exists.');
      }
    } catch (e) {
      return _rollbackAfterPersistFailure(id, trigger, e);
    }
    return AlarmScheduled(trigger);
  }

  /// Marks the alarm enabled and schedules its next occurrence.
  ///
  /// The alarm stays enabled in the database even when the outcome is not
  /// [AlarmScheduled] (e.g. nothing schedulable yet): enabled is desired
  /// state, the outcome describes what the OS holds.
  Future<AlarmScheduleResult> enableAlarm(int id, {DateTime? now}) async {
    try {
      final bool updated = await _repository.setAlarmEnabled(id, true);
      if (!updated) {
        return AlarmScheduleFailed(StateError('Alarm $id not found.'));
      }
    } catch (e) {
      return AlarmScheduleFailed(e);
    }
    return scheduleAlarm(id, now: now);
  }

  /// Recomputes and re-schedules the alarm (cancel -> calculate -> schedule).
  ///
  /// Explicit entry point for "something changed, recompute" flows (alarm
  /// edits in a later phase). Identical to [scheduleAlarm], which already
  /// cancels any previous native schedule for the id before scheduling the
  /// newly calculated trigger. Post-fire chaining uses
  /// [rescheduleAfterFire] instead: same engine, plus the fired-token guard
  /// that rejects stale and duplicate deliveries.
  Future<AlarmScheduleResult> rescheduleAlarm(int id, {DateTime? now}) {
    return scheduleAlarm(id, now: now);
  }

  /// Handles a just-fired alarm: completes one-time alarms, chains
  /// recurring ones to their next occurrence.
  ///
  /// Flow: load -> skip when disabled (cancelling strays) -> reject when
  /// [firedTriggerAt] no longer matches the stored schedule (stale,
  /// duplicate, cancelled, or already-handled fire; the database is left
  /// untouched) -> complete one-time alarms (cancel stray, clear trigger) ->
  /// otherwise require exact-alarm permission -> cancel previous native
  /// schedule -> schedule the next occurrence strictly after
  /// [firedTriggerAt] -> persist it to `nextTriggerAt`. Fresh row state is
  /// loaded, so edits made between scheduling and stopping take effect on
  /// the next ring.
  ///
  /// Idempotency comes from the stored trigger: the first handling either
  /// persists a strictly-later trigger or clears it, so any repeat delivery
  /// of the same [firedTriggerAt] mismatches and is rejected without
  /// touching the database. Never throws for domain or scheduler failures;
  /// see [AlarmScheduleResult].
  Future<AlarmScheduleResult> rescheduleAfterFire({
    required int alarmId,
    required DateTime firedTriggerAt,
  }) async {
    final Alarm? alarm = await _repository.getAlarmById(alarmId);
    if (alarm == null) {
      return AlarmScheduleFailed(StateError('Alarm $alarmId not found.'));
    }
    if (!alarm.enabled) {
      try {
        await _scheduler.cancelAlarm(alarmId: alarmId);
        await _clearNextTrigger(alarmId);
      } catch (e) {
        return AlarmScheduleFailed(e);
      }
      return const AlarmDisabled();
    }
    // Tokens are millisecond-granular (native ledger keys); comparing at
    // that granularity keeps Dart and native in agreement.
    if (alarm.nextTriggerAt?.millisecondsSinceEpoch !=
        firedTriggerAt.millisecondsSinceEpoch) {
      return const AlarmNotSchedulable(
        'Fired trigger is not the current schedule.',
      );
    }
    final AlarmSchedule schedule = _toSchedule(alarm);
    if (schedule.repeatType == RepeatType.once) {
      try {
        await _scheduler.cancelAlarm(alarmId: alarmId);
        await _clearNextTrigger(alarmId);
      } catch (e) {
        return AlarmScheduleFailed(e);
      }
      return const AlarmNotSchedulable('One-time alarm already fired.');
    }
    final DateTime? next = _calculator.nextOccurrence(
      schedule: schedule,
      now: firedTriggerAt,
    );
    if (next == null || !next.isAfter(firedTriggerAt)) {
      // Defensive: recurring schedules always yield a strictly-later next.
      // Never re-fire the trigger that just fired.
      try {
        await _scheduler.cancelAlarm(alarmId: alarmId);
        await _clearNextTrigger(alarmId);
      } catch (e) {
        return AlarmScheduleFailed(e);
      }
      return const AlarmNotSchedulable('No further occurrence.');
    }
    final bool allowed;
    try {
      allowed = await _scheduler.canScheduleExactAlarms();
    } catch (e) {
      return AlarmScheduleFailed(e);
    }
    if (!allowed) {
      try {
        await _scheduler.cancelAlarm(alarmId: alarmId);
        await _clearNextTrigger(alarmId);
      } catch (e) {
        return AlarmScheduleFailed(e);
      }
      return const AlarmPermissionMissing();
    }
    try {
      await _scheduler.cancelAlarm(alarmId: alarmId);
    } catch (e) {
      return AlarmScheduleFailed(e);
    }
    try {
      await _scheduler.scheduleExactAlarm(
        alarmId: alarmId,
        triggerAt: next,
        fireConfig: AlarmFireConfig(
          label: alarm.label,
          vibrationEnabled: alarm.vibrationEnabled,
        ),
      );
    } catch (e) {
      await _clearBestEffort(alarmId);
      return AlarmScheduleFailed(e);
    }
    try {
      final bool persisted = await _persistNextTrigger(alarmId, next);
      if (!persisted) {
        throw StateError('Alarm $alarmId no longer exists.');
      }
    } catch (e) {
      return _rollbackAfterPersistFailure(alarmId, next, e);
    }
    return AlarmScheduled(next);
  }

  /// Snoozes a ringing alarm: reschedules the current occurrence to
  /// `now + snoozeMinutes` through the normal native pipeline.
  ///
  /// Flow: load -> skip when disabled (cancelling strays) -> reject when
  /// [firedTriggerAt] no longer matches the stored schedule (stale,
  /// duplicate, or already-snoozed ring; the database is left untouched)
  /// -> reject when snooze is disabled, misconfigured, or exhausted (the
  /// used count comes from the episode's history row) -> otherwise require
  /// exact-alarm permission -> cancel previous native schedule -> schedule
  /// the snooze trigger -> persist it to `nextTriggerAt`.
  ///
  /// The snooze is temporary: hour/minute/recurrence are never modified,
  /// so the snoozed ring chains back to the normal occurrence via
  /// [rescheduleAfterFire]. Callers record the snooze (history count,
  /// pending target) and THEN stop the native ring, so the post-fire
  /// handoff finds a diverted token and stays out of the way. Never
  /// throws for domain or scheduler failures; see [AlarmScheduleResult].
  Future<AlarmScheduleResult> snoozeAlarm({
    required int alarmId,
    required DateTime firedTriggerAt,
    DateTime? now,
  }) async {
    final DateTime at = now ?? DateTime.now();
    final Alarm? alarm = await _repository.getAlarmById(alarmId);
    if (alarm == null) {
      return AlarmScheduleFailed(StateError('Alarm $alarmId not found.'));
    }
    if (!alarm.enabled) {
      try {
        await _scheduler.cancelAlarm(alarmId: alarmId);
        await _clearNextTrigger(alarmId);
      } catch (e) {
        return AlarmScheduleFailed(e);
      }
      return const AlarmDisabled();
    }
    if (alarm.nextTriggerAt?.millisecondsSinceEpoch !=
        firedTriggerAt.millisecondsSinceEpoch) {
      return const AlarmNotSchedulable(
        'Fired trigger is not the current schedule.',
      );
    }
    if (!alarm.snoozeEnabled) {
      return const AlarmNotSchedulable('Snooze is disabled for this alarm.');
    }
    if (!SnoozePolicy.isValidMinutes(alarm.snoozeMinutes)) {
      return const AlarmNotSchedulable('Snooze duration is invalid.');
    }
    if (!SnoozePolicy.isValidMaxCount(alarm.snoozeMaxCount)) {
      return const AlarmNotSchedulable('Snooze limit is invalid.');
    }
    final int used = await _usedSnoozes(alarmId);
    if (!SnoozePolicy.canSnooze(
      enabled: alarm.snoozeEnabled,
      minutes: alarm.snoozeMinutes,
      maxCount: alarm.snoozeMaxCount,
      usedCount: used,
    )) {
      return const AlarmNotSchedulable('No snoozes remaining.');
    }
    final DateTime target =
        at.add(Duration(minutes: alarm.snoozeMinutes));
    final bool allowed;
    try {
      allowed = await _scheduler.canScheduleExactAlarms();
    } catch (e) {
      return AlarmScheduleFailed(e);
    }
    if (!allowed) {
      try {
        await _scheduler.cancelAlarm(alarmId: alarmId);
        await _clearNextTrigger(alarmId);
      } catch (e) {
        return AlarmScheduleFailed(e);
      }
      return const AlarmPermissionMissing();
    }
    try {
      await _scheduler.cancelAlarm(alarmId: alarmId);
    } catch (e) {
      return AlarmScheduleFailed(e);
    }
    try {
      await _scheduler.scheduleExactAlarm(
        alarmId: alarmId,
        triggerAt: target,
        fireConfig: AlarmFireConfig(
          label: alarm.label,
          vibrationEnabled: alarm.vibrationEnabled,
        ),
      );
    } catch (e) {
      await _clearBestEffort(alarmId);
      return AlarmScheduleFailed(e);
    }
    try {
      final bool persisted = await _persistNextTrigger(alarmId, target);
      if (!persisted) {
        throw StateError('Alarm $alarmId no longer exists.');
      }
    } catch (e) {
      return _rollbackAfterPersistFailure(alarmId, target, e);
    }
    return AlarmScheduled(target);
  }

  /// Snoozes already used in the alarm's open episode: the newest history
  /// row's count when that row is still open, else 0. Only the newest row
  /// can own an open episode (see `ringing_history.dart`). Read failures
  /// degrade to 0: a failed count read must not strand the ringing
  /// screen, and the limit re-applies once reads work.
  Future<int> _usedSnoozes(int alarmId) async {
    final AlarmHistoryRepository? history = _history;
    if (history == null) {
      return 0;
    }
    try {
      final List<AlarmHistoryData> rows =
          await history.getHistoryForAlarm(alarmId);
      if (rows.isNotEmpty &&
          rows.first.result == AlarmResult.ongoing.dbValue) {
        final int count = rows.first.snoozeCount;
        return count < 0 ? 0 : count;
      }
    } catch (_) {
      return 0;
    }
    return 0;
  }

  /// Reconciles every stored alarm with the OS after boot (or any event
  /// that may have wiped native schedules).
  ///
  /// Flow per alarm: enabled -> [scheduleAlarm] (recomputes the correct
  /// trigger strictly after [now], re-issues the native schedule through
  /// the alarm's own PendingIntent slot, persists it); disabled ->
  /// [cancelAlarm] (removes any stale native schedule/ledger entry, clears
  /// the trigger). Re-issuing an already-correct trigger is the repair,
  /// not a duplicate: the slot and ledger token are overwritten in place.
  /// Each alarm is isolated: unexpected errors are counted in the report
  /// and the pass continues with the rest.
  ///
  /// [now] defaults to the current local time and exists so tests can pin
  /// time deterministically. Only a total failure to load the alarm list
  /// throws; per-alarm problems are reported via [ReconciliationReport].
  Future<ReconciliationReport> reconcileSchedules({DateTime? now}) async {
    final DateTime ref = now ?? DateTime.now();
    final List<Alarm> alarms = await _repository.getAlarms();
    int scheduled = 0;
    int unschedulable = 0;
    int disabledCleared = 0;
    int permissionMissing = 0;
    int failed = 0;
    for (final Alarm alarm in alarms) {
      if (!alarm.enabled) {
        try {
          await cancelAlarm(alarm.id);
          disabledCleared++;
        } catch (_) {
          failed++;
        }
        continue;
      }
      final AlarmScheduleResult? preserved =
          await _preservePendingSnooze(alarm, ref);
      final AlarmScheduleResult result;
      try {
        result = preserved ?? await scheduleAlarm(alarm.id, now: ref);
      } catch (_) {
        failed++;
        continue;
      }
      switch (result) {
        case AlarmScheduled():
          scheduled++;
        case AlarmNotSchedulable():
          unschedulable++;
        case AlarmDisabled():
          // Row flipped to disabled between the listing and the scheduling;
          // scheduleAlarm already cancelled its strays and cleared it.
          disabledCleared++;
        case AlarmPermissionMissing():
          permissionMissing++;
        case AlarmScheduleFailed():
          failed++;
      }
    }
    return ReconciliationReport(
      processed: alarms.length,
      scheduled: scheduled,
      unschedulable: unschedulable,
      disabledCleared: disabledCleared,
      permissionMissing: permissionMissing,
      failed: failed,
    );
  }

  /// Re-issues a pending snooze trigger instead of recomputing it.
  ///
  /// A snoozed alarm holds its temporary trigger in `nextTriggerAt` while
  /// its episode row stays open. Reconciliation (boot, app start,
  /// lifecycle) must re-issue that stored trigger as-is — recomputing
  /// from hour/minute/recurrence would silently cancel the snooze.
  /// Returns the outcome to report, or `null` when this alarm holds no
  /// pending snooze (the normal [scheduleAlarm] path applies). A stale
  /// open row over a normal future trigger re-issues the same value,
  /// which is harmless: same slot, same token, same fire config.
  Future<AlarmScheduleResult?> _preservePendingSnooze(
    Alarm alarm,
    DateTime now,
  ) async {
    final AlarmHistoryRepository? history = _history;
    final DateTime? stored = alarm.nextTriggerAt;
    if (history == null || stored == null || !stored.isAfter(now)) {
      return null;
    }
    final List<AlarmHistoryData> rows;
    try {
      rows = await history.getHistoryForAlarm(alarm.id);
    } catch (_) {
      return null;
    }
    if (rows.isEmpty || rows.first.result != AlarmResult.ongoing.dbValue) {
      return null;
    }
    final bool allowed;
    try {
      allowed = await _scheduler.canScheduleExactAlarms();
    } catch (e) {
      return AlarmScheduleFailed(e);
    }
    if (!allowed) {
      try {
        await _scheduler.cancelAlarm(alarmId: alarm.id);
        await _clearNextTrigger(alarm.id);
      } catch (e) {
        return AlarmScheduleFailed(e);
      }
      return const AlarmPermissionMissing();
    }
    try {
      await _scheduler.cancelAlarm(alarmId: alarm.id);
      await _scheduler.scheduleExactAlarm(
        alarmId: alarm.id,
        triggerAt: stored,
        fireConfig: AlarmFireConfig(
          label: alarm.label,
          vibrationEnabled: alarm.vibrationEnabled,
        ),
      );
    } catch (e) {
      await _clearBestEffort(alarm.id);
      return AlarmScheduleFailed(e);
    }
    return AlarmScheduled(stored);
  }

  /// Cancels the OS schedule for [id] and clears its stored trigger.
  ///
  /// Does not delete the database record. Idempotent: unknown ids are a
  /// successful no-op. Propagates bridge/database errors to the caller.
  Future<void> cancelAlarm(int id) async {
    await _scheduler.cancelAlarm(alarmId: id);
    await _clearNextTrigger(id);
  }

  /// Marks the alarm disabled, cancels its OS schedule, clears its trigger.
  ///
  /// Idempotent: unknown ids are a successful no-op. Propagates
  /// bridge/database errors to the caller.
  Future<void> disableAlarm(int id) async {
    await _repository.setAlarmEnabled(id, false);
    await cancelAlarm(id);
  }

  /// Translates a stored row into calculator input.
  AlarmSchedule _toSchedule(Alarm alarm) {
    final int? mask = alarm.repeatDays;
    return AlarmSchedule(
      repeatType: RepeatType.fromDbValue(alarm.repeatType),
      hour: alarm.hour,
      minute: alarm.minute,
      onceDate: alarm.onceDate,
      repeatDays: mask == null ? RepeatDays.none : RepeatDays(mask),
    );
  }

  /// Explains why [alarm] produced no occurrence (call only when it did not).
  String _unschedulableReason(Alarm alarm) {
    final RepeatType repeatType = RepeatType.fromDbValue(alarm.repeatType);
    if (repeatType == RepeatType.once && alarm.onceDate == null) {
      return 'One-time alarm has no date.';
    }
    if (repeatType == RepeatType.once) {
      return 'One-time alarm is in the past.';
    }
    return 'No weekday is selected.';
  }

  /// Stores [trigger] as the alarm's current OS schedule.
  /// Returns `false` when the row no longer exists.
  Future<bool> _persistNextTrigger(int id, DateTime trigger) async {
    final Alarm? alarm = await _repository.getAlarmById(id);
    if (alarm == null) {
      return false;
    }
    return _repository.updateAlarm(
      alarm.copyWith(nextTriggerAt: Value(trigger)),
    );
  }

  /// Clears the stored trigger (nothing is currently scheduled).
  /// Missing rows are a silent no-op.
  Future<void> _clearNextTrigger(int id) async {
    final Alarm? alarm = await _repository.getAlarmById(id);
    if (alarm == null) {
      return;
    }
    await _repository.updateAlarm(
      alarm.copyWith(nextTriggerAt: const Value(null)),
    );
  }

  /// Best-effort trigger cleanup that never masks the original failure.
  Future<void> _clearBestEffort(int id) async {
    try {
      await _clearNextTrigger(id);
    } catch (_) {
      // Intentionally ignored: cleanup failure must not replace the error
      // that caused the cleanup. The returned Failed outcome stays truthful
      // about the operation itself.
    }
  }

  /// Repairs state after a native schedule that could not be persisted:
  /// roll the native schedule back, clear the stored trigger, and report.
  /// Only when the rollback cancel itself throws do we report a leaked
  /// native schedule via `scheduledButNotPersisted`.
  Future<AlarmScheduleResult> _rollbackAfterPersistFailure(
    int id,
    DateTime trigger,
    Object error,
  ) async {
    try {
      await _scheduler.cancelAlarm(alarmId: id);
    } catch (_) {
      await _clearBestEffort(id);
      return AlarmScheduleFailed(error, scheduledButNotPersisted: trigger);
    }
    await _clearBestEffort(id);
    return AlarmScheduleFailed(error);
  }
}
