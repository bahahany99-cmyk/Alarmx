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
//     alarm alive; recurring re-scheduling after firing, and boot-time
//     re-scheduling, belong to a later native phase.
//   - No scheduling logic lives in DAOs, entities, widgets, the repository
//     SQL, or MainActivity: repositories persist, the native scheduler talks
//     to Android, this coordinator orchestrates.
//   - `updatedAt` is intentionally left untouched by coordinator writes; row
//     timestamp policy belongs to a future repository-layer pass.
//
// Failure philosophy: scheduling calls never pretend success. The schedule
// family (`scheduleAlarm`, `enableAlarm`, `rescheduleAlarm`) never throws
// for domain/scheduler failures and reports everything via
// [AlarmScheduleResult]. `cancelAlarm`/`disableAlarm` are idempotent
// fire-and-forget state changes (unknown ids are a successful no-op) and
// propagate bridge/database errors to the caller instead.

import 'package:drift/drift.dart';

import '../alarms/native_alarm_scheduler.dart';
import '../database/database.dart';
import '../models/models.dart';
import '../repositories/alarm_repository.dart';
import 'alarm_schedule.dart';
import 'alarm_schedule_result.dart';
import 'next_occurrence_calculator.dart';

/// Orchestrates database state and OS alarm schedules.
class AlarmSchedulingCoordinator {
  const AlarmSchedulingCoordinator({
    required AlarmRepository repository,
    required NativeAlarmScheduler scheduler,
    NextOccurrenceCalculator calculator = const NextOccurrenceCalculator(),
  })  : _repository = repository,
        _scheduler = scheduler,
        _calculator = calculator;

  final AlarmRepository _repository;
  final NativeAlarmScheduler _scheduler;
  final NextOccurrenceCalculator _calculator;

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
      await _scheduler.scheduleExactAlarm(alarmId: id, triggerAt: trigger);
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
  /// edits in a later phase, post-fire chaining). Identical to
  /// [scheduleAlarm], which already cancels any previous native schedule
  /// for the id before scheduling the newly calculated trigger.
  Future<AlarmScheduleResult> rescheduleAlarm(int id, {DateTime? now}) {
    return scheduleAlarm(id, now: now);
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
