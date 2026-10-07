import 'package:alarmx/core/database/database.dart';
import 'package:alarmx/core/models/models.dart';
import 'package:alarmx/core/scheduling/alarm_schedule_result.dart';
import 'package:alarmx/core/scheduling/alarm_scheduling_coordinator.dart';
import 'package:alarmx/core/scheduling/snooze_policy.dart';
import 'package:alarmx/features/ringing_alarm/ringing_history.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';

import '../../support/test_doubles.dart';

// Snooze tests: pure policy, episode linkage, coordinator snooze +
// pending-snooze preservation. Real in-memory stack, pinned times.

void main() {
  late TestStack stack;

  setUp(() {
    stack = TestStack();
  });

  tearDown(() async {
    await stack.close();
  });

  /// Schedules [id] at pinned [now]; returns the stored trigger.
  Future<DateTime> scheduleAt(int id, DateTime now) async {
    final AlarmScheduleResult result =
        await stack.coordinator.scheduleAlarm(id, now: now);
    expect(result, isA<AlarmScheduled>());
    final Alarm? alarm = await stack.repository.getAlarmById(id);
    return alarm!.nextTriggerAt!;
  }

  Future<int> openEpisode(
    int alarmId,
    DateTime startedAt, {
    int snoozeCount = 0,
    DateTime? pendingTarget,
  }) {
    return stack.history.insertHistory(
      AlarmHistoryCompanion.insert(
        alarmId: Value<int?>(alarmId),
        startedAt: startedAt,
        stoppedAt: Value<DateTime?>(pendingTarget),
        result: Value<String>(AlarmResult.ongoing.dbValue),
        snoozeCount: Value<int>(snoozeCount),
      ),
    );
  }

  Future<List<AlarmHistoryData>> rowsFor(int alarmId) {
    return stack.history.getHistoryForAlarm(alarmId);
  }

  group('SnoozePolicy', () {
    test('minute bounds', () {
      expect(SnoozePolicy.isValidMinutes(0), isFalse);
      expect(SnoozePolicy.isValidMinutes(-5), isFalse);
      expect(SnoozePolicy.isValidMinutes(1), isTrue);
      expect(SnoozePolicy.isValidMinutes(30), isTrue);
      expect(SnoozePolicy.isValidMinutes(60), isTrue);
      expect(SnoozePolicy.isValidMinutes(61), isFalse);
    });

    test('max-count bounds', () {
      expect(SnoozePolicy.isValidMaxCount(-1), isTrue);
      expect(SnoozePolicy.isValidMaxCount(0), isFalse);
      expect(SnoozePolicy.isValidMaxCount(-2), isFalse);
      expect(SnoozePolicy.isValidMaxCount(1), isTrue);
      expect(SnoozePolicy.isUnlimited(-1), isTrue);
      expect(SnoozePolicy.isUnlimited(3), isFalse);
    });

    test('canSnooze matrix', () {
      const bool can = true;
      // Disabled or misconfigured: never.
      expect(
        SnoozePolicy.canSnooze(
          enabled: false,
          minutes: 5,
          maxCount: 3,
          usedCount: 0,
        ),
        isFalse,
      );
      expect(
        SnoozePolicy.canSnooze(
          enabled: can,
          minutes: 0,
          maxCount: 3,
          usedCount: 0,
        ),
        isFalse,
      );
      expect(
        SnoozePolicy.canSnooze(
          enabled: can,
          minutes: 5,
          maxCount: 0,
          usedCount: 0,
        ),
        isFalse,
      );
      expect(
        SnoozePolicy.canSnooze(
          enabled: can,
          minutes: 5,
          maxCount: 3,
          usedCount: -1,
        ),
        isFalse,
      );
      // Limited: until the cap, then never.
      expect(
        SnoozePolicy.canSnooze(
          enabled: can,
          minutes: 5,
          maxCount: 3,
          usedCount: 0,
        ),
        isTrue,
      );
      expect(
        SnoozePolicy.canSnooze(
          enabled: can,
          minutes: 5,
          maxCount: 3,
          usedCount: 2,
        ),
        isTrue,
      );
      expect(
        SnoozePolicy.canSnooze(
          enabled: can,
          minutes: 5,
          maxCount: 3,
          usedCount: 3,
        ),
        isFalse,
      );
      expect(
        SnoozePolicy.canSnooze(
          enabled: can,
          minutes: 5,
          maxCount: 3,
          usedCount: 9,
        ),
        isFalse,
      );
      // Unlimited: always.
      expect(
        SnoozePolicy.canSnooze(
          enabled: can,
          minutes: 5,
          maxCount: -1,
          usedCount: 0,
        ),
        isTrue,
      );
      expect(
        SnoozePolicy.canSnooze(
          enabled: can,
          minutes: 5,
          maxCount: -1,
          usedCount: 100,
        ),
        isTrue,
      );
    });

    test('remainingSnoozes', () {
      expect(
        SnoozePolicy.remainingSnoozes(maxCount: -1, usedCount: 50),
        isNull,
      );
      expect(
        SnoozePolicy.remainingSnoozes(maxCount: 3, usedCount: 1),
        2,
      );
      expect(
        SnoozePolicy.remainingSnoozes(maxCount: 3, usedCount: 3),
        0,
      );
      expect(
        SnoozePolicy.remainingSnoozes(maxCount: 0, usedCount: 0),
        0,
      );
    });
  });

  group('resolveRingHistory', () {
    final DateTime ring = DateTime(2026, 10, 8, 7, 0);
    final DateTime target = DateTime(2026, 10, 8, 7, 5);

    test('no rows starts fresh', () {
      const RingHistoryResolution resolution = RingHistoryResolution(
        RingHistoryAction.startFresh,
        null,
      );
      expect(resolution.action, RingHistoryAction.startFresh);
      final RingHistoryResolution actual = resolveRingHistory(
        rowsNewestFirst: const <AlarmHistoryData>[],
        firedTriggerMillis: ring.millisecondsSinceEpoch,
      );
      expect(actual.action, RingHistoryAction.startFresh);
      expect(actual.row, isNull);
    });

    test('closed latest row starts fresh', () async {
      final int id = await stack.insertAlarm();
      await stack.history.insertHistory(
        AlarmHistoryCompanion.insert(
          alarmId: Value<int?>(id),
          startedAt: ring,
          stoppedAt: Value<DateTime?>(target),
          result: Value<String>(AlarmResult.success.dbValue),
        ),
      );
      final RingHistoryResolution actual = resolveRingHistory(
        rowsNewestFirst: await rowsFor(id),
        firedTriggerMillis: target.millisecondsSinceEpoch,
      );
      expect(actual.action, RingHistoryAction.startFresh);
      expect(actual.row, isNull);
    });

    test('open row with matching pending target is reused', () async {
      final int id = await stack.insertAlarm();
      await openEpisode(id, ring, snoozeCount: 1, pendingTarget: target);
      final RingHistoryResolution actual = resolveRingHistory(
        rowsNewestFirst: await rowsFor(id),
        firedTriggerMillis: target.millisecondsSinceEpoch,
      );
      expect(actual.action, RingHistoryAction.reuse);
      expect(actual.row?.snoozeCount, 1);
    });

    test('open row with mismatched target is stale', () async {
      final int id = await stack.insertAlarm();
      await openEpisode(id, ring, snoozeCount: 1, pendingTarget: target);
      final RingHistoryResolution actual = resolveRingHistory(
        rowsNewestFirst: await rowsFor(id),
        // A different occurrence fired (e.g. after an edit rewrote it).
        firedTriggerMillis:
            DateTime(2026, 10, 9, 7, 0).millisecondsSinceEpoch,
      );
      expect(actual.action, RingHistoryAction.closeStaleAndStart);
      expect(actual.row?.snoozeCount, 1);
    });

    test('open row without a pending target is stale', () async {
      final int id = await stack.insertAlarm();
      await openEpisode(id, ring);
      final RingHistoryResolution actual = resolveRingHistory(
        rowsNewestFirst: await rowsFor(id),
        firedTriggerMillis: target.millisecondsSinceEpoch,
      );
      expect(actual.action, RingHistoryAction.closeStaleAndStart);
    });

    test('null token never reuses', () async {
      final int id = await stack.insertAlarm();
      await openEpisode(id, ring, snoozeCount: 1, pendingTarget: target);
      final RingHistoryResolution actual = resolveRingHistory(
        rowsNewestFirst: await rowsFor(id),
        firedTriggerMillis: null,
      );
      expect(actual.action, RingHistoryAction.closeStaleAndStart);
    });

    test('older rows are never resurrected', () async {
      final int id = await stack.insertAlarm();
      await openEpisode(id, ring, snoozeCount: 2, pendingTarget: target);
      await stack.history.insertHistory(
        AlarmHistoryCompanion.insert(
          alarmId: Value<int?>(id),
          startedAt: target,
          stoppedAt: Value<DateTime?>(target),
          result: Value<String>(AlarmResult.success.dbValue),
        ),
      );
      final RingHistoryResolution actual = resolveRingHistory(
        rowsNewestFirst: await rowsFor(id),
        firedTriggerMillis: target.millisecondsSinceEpoch,
      );
      expect(actual.action, RingHistoryAction.startFresh);
    });
  });

  group('snoozeAlarm', () {
    final DateTime morning = DateTime(2026, 10, 8, 6, 55);

    test('missing alarm fails', () async {
      final AlarmScheduleResult result = await stack.coordinator.snoozeAlarm(
        alarmId: 999,
        firedTriggerAt: morning,
        now: morning,
      );
      expect(result, isA<AlarmScheduleFailed>());
    });

    test('disabled alarm clears strays', () async {
      final int id = await stack.insertAlarm(enabled: false);
      final AlarmScheduleResult result = await stack.coordinator.snoozeAlarm(
        alarmId: id,
        firedTriggerAt: morning,
        now: morning,
      );
      expect(result, isA<AlarmDisabled>());
      expect(
        (await stack.repository.getAlarmById(id))?.nextTriggerAt,
        isNull,
      );
    });

    test('stale token is rejected without touching native', () async {
      final int id = await stack.insertAlarm();
      final DateTime stored = await scheduleAt(id, morning);
      stack.scheduler.calls.clear();
      final AlarmScheduleResult result = await stack.coordinator.snoozeAlarm(
        alarmId: id,
        firedTriggerAt: stored.add(const Duration(minutes: 1)),
        now: stored,
      );
      expect(result, isA<AlarmNotSchedulable>());
      expect(stack.scheduler.calls, isEmpty);
      expect(
        (await stack.repository.getAlarmById(id))?.nextTriggerAt,
        stored,
      );
    });

    test('disabled snooze is rejected without touching native', () async {
      final int id = await stack.insertAlarm();
      final DateTime stored = await scheduleAt(id, morning);
      final Alarm? alarm = await stack.repository.getAlarmById(id);
      await stack.repository
          .updateAlarm(alarm!.copyWith(snoozeEnabled: false));
      stack.scheduler.calls.clear();
      final AlarmScheduleResult result = await stack.coordinator.snoozeAlarm(
        alarmId: id,
        firedTriggerAt: stored,
        now: stored,
      );
      expect(result, isA<AlarmNotSchedulable>());
      expect(
        (result as AlarmNotSchedulable).reason,
        contains('disabled'),
      );
      expect(stack.scheduler.calls, isEmpty);
    });

    test('invalid snooze config is rejected', () async {
      final int id = await stack.insertAlarm();
      final DateTime stored = await scheduleAt(id, morning);
      final Alarm? alarm = await stack.repository.getAlarmById(id);
      await stack.repository
          .updateAlarm(alarm!.copyWith(snoozeMinutes: 0));
      stack.scheduler.calls.clear();
      final AlarmScheduleResult minutesResult =
          await stack.coordinator.snoozeAlarm(
        alarmId: id,
        firedTriggerAt: stored,
        now: stored,
      );
      expect(minutesResult, isA<AlarmNotSchedulable>());
      expect(stack.scheduler.calls, isEmpty);

      final Alarm? again = await stack.repository.getAlarmById(id);
      await stack.repository.updateAlarm(
        again!.copyWith(snoozeMinutes: 5, snoozeMaxCount: 0),
      );
      final AlarmScheduleResult countResult =
          await stack.coordinator.snoozeAlarm(
        alarmId: id,
        firedTriggerAt: stored,
        now: stored,
      );
      expect(countResult, isA<AlarmNotSchedulable>());
      expect(stack.scheduler.calls, isEmpty);
    });

    test('exhausted count is rejected', () async {
      final int id = await stack.insertAlarm();
      final DateTime stored = await scheduleAt(id, morning);
      await openEpisode(id, stored, snoozeCount: 3, pendingTarget: stored);
      stack.scheduler.calls.clear();
      final AlarmScheduleResult result = await stack.coordinator.snoozeAlarm(
        alarmId: id,
        firedTriggerAt: stored,
        now: stored,
      );
      expect(result, isA<AlarmNotSchedulable>());
      expect(stack.scheduler.calls, isEmpty);
    });

    test('unlimited snooze ignores the count', () async {
      final int id = await stack.insertAlarm();
      final DateTime stored = await scheduleAt(id, morning);
      final Alarm? alarm = await stack.repository.getAlarmById(id);
      await stack.repository
          .updateAlarm(alarm!.copyWith(snoozeMaxCount: -1));
      await openEpisode(id, stored, snoozeCount: 100, pendingTarget: stored);
      final AlarmScheduleResult result = await stack.coordinator.snoozeAlarm(
        alarmId: id,
        firedTriggerAt: stored,
        now: stored,
      );
      expect(result, isA<AlarmScheduled>());
      expect(
        (result as AlarmScheduled).triggerAt,
        stored.add(const Duration(minutes: 5)),
      );
    });

    test('snooze schedules now+minutes and preserves recurrence', () async {
      final int id = await stack.insertAlarm(hour: 7, minute: 0);
      final DateTime stored = await scheduleAt(id, morning);
      await openEpisode(id, stored);
      stack.scheduler.calls.clear();
      stack.scheduler.scheduledTriggers.clear();
      final DateTime pressed = stored.add(const Duration(seconds: 30));
      final AlarmScheduleResult result = await stack.coordinator.snoozeAlarm(
        alarmId: id,
        firedTriggerAt: stored,
        now: pressed,
      );
      expect(result, isA<AlarmScheduled>());
      final DateTime target = pressed.add(const Duration(minutes: 5));
      expect((result as AlarmScheduled).triggerAt, target);
      expect(stack.scheduler.calls, <String>['cancel:$id', 'schedule:$id']);
      expect(stack.scheduler.scheduledTriggers.single, target);
      // Fire config travels with the snooze schedule.
      expect(
        stack.scheduler.scheduledConfigs.single?.vibrationEnabled,
        isTrue,
      );
      final Alarm? after = await stack.repository.getAlarmById(id);
      expect(after?.nextTriggerAt, target);
      // The normal recurrence is untouched by the temporary snooze.
      expect(after?.hour, 7);
      expect(after?.minute, 0);
      expect(after?.repeatType, RepeatType.daily.dbValue);
    });

    test('snooze works for once alarms', () async {
      final int id = await stack.insertAlarm(
        hour: 7,
        minute: 0,
        repeatType: RepeatType.once,
        onceDate: DateTime(2026, 10, 8),
      );
      final DateTime stored = await scheduleAt(id, morning);
      await openEpisode(id, stored);
      final AlarmScheduleResult result = await stack.coordinator.snoozeAlarm(
        alarmId: id,
        firedTriggerAt: stored,
        now: stored,
      );
      expect(result, isA<AlarmScheduled>());
      expect(
        (result as AlarmScheduled).triggerAt,
        stored.add(const Duration(minutes: 5)),
      );
    });

    test('snooze diverts the post-fire handoff', () async {
      final int id = await stack.insertAlarm(hour: 7, minute: 0);
      final DateTime stored = await scheduleAt(id, morning);
      await openEpisode(id, stored);
      final AlarmScheduleResult snoozed =
          await stack.coordinator.snoozeAlarm(
        alarmId: id,
        firedTriggerAt: stored,
        now: stored,
      );
      final DateTime target = (snoozed as AlarmScheduled).triggerAt;
      // The native stop reports the ORIGINAL token; the diverted stored
      // trigger rejects it, so no normal chaining stomps the snooze.
      final AlarmScheduleResult handoff =
          await stack.coordinator.rescheduleAfterFire(
        alarmId: id,
        firedTriggerAt: stored,
      );
      expect(handoff, isA<AlarmNotSchedulable>());
      expect(
        (await stack.repository.getAlarmById(id))?.nextTriggerAt,
        target,
      );
    });

    test('snoozed ring chains back to the normal occurrence', () async {
      final int id = await stack.insertAlarm(hour: 7, minute: 0);
      final DateTime stored = await scheduleAt(id, morning);
      await openEpisode(id, stored);
      final AlarmScheduleResult snoozed =
          await stack.coordinator.snoozeAlarm(
        alarmId: id,
        firedTriggerAt: stored,
        now: stored,
      );
      final DateTime target = (snoozed as AlarmScheduled).triggerAt;
      // The snoozed ring completes: its own token chains normally.
      final AlarmScheduleResult chained =
          await stack.coordinator.rescheduleAfterFire(
        alarmId: id,
        firedTriggerAt: target,
      );
      expect(chained, isA<AlarmScheduled>());
      expect(
        (chained as AlarmScheduled).triggerAt,
        DateTime(2026, 10, 9, 7, 0),
      );
    });

    test('snoozed once alarm completes after its snooze', () async {
      final int id = await stack.insertAlarm(
        hour: 7,
        minute: 0,
        repeatType: RepeatType.once,
        onceDate: DateTime(2026, 10, 8),
      );
      final DateTime stored = await scheduleAt(id, morning);
      await openEpisode(id, stored);
      final AlarmScheduleResult snoozed =
          await stack.coordinator.snoozeAlarm(
        alarmId: id,
        firedTriggerAt: stored,
        now: stored,
      );
      final AlarmScheduleResult chained =
          await stack.coordinator.rescheduleAfterFire(
        alarmId: id,
        firedTriggerAt: (snoozed as AlarmScheduled).triggerAt,
      );
      expect(chained, isA<AlarmNotSchedulable>());
      expect(
        (await stack.repository.getAlarmById(id))?.nextTriggerAt,
        isNull,
      );
    });

    test('permission missing clears the dead schedule', () async {
      final int id = await stack.insertAlarm();
      final DateTime stored = await scheduleAt(id, morning);
      await openEpisode(id, stored);
      stack.scheduler.canSchedule = false;
      final AlarmScheduleResult result = await stack.coordinator.snoozeAlarm(
        alarmId: id,
        firedTriggerAt: stored,
        now: stored,
      );
      expect(result, isA<AlarmPermissionMissing>());
      expect(
        (await stack.repository.getAlarmById(id))?.nextTriggerAt,
        isNull,
      );
    });

    test('without history the count reads as zero', () async {
      final AlarmSchedulingCoordinator bare =
          AlarmSchedulingCoordinator(
        repository: stack.repository,
        scheduler: stack.scheduler,
      );
      final int id = await stack.insertAlarm();
      final DateTime stored = await scheduleAt(id, morning);
      // An exhausted episode exists, but the bare coordinator cannot see
      // history and snoozes anyway (documented degradation).
      await openEpisode(id, stored, snoozeCount: 99, pendingTarget: stored);
      final AlarmScheduleResult result = await bare.snoozeAlarm(
        alarmId: id,
        firedTriggerAt: stored,
        now: stored,
      );
      expect(result, isA<AlarmScheduled>());
    });
  });

  group('reconcileSchedules preserves pending snoozes', () {
    final DateTime morning = DateTime(2026, 10, 8, 6, 55);

    test('pending snooze is re-issued as-is', () async {
      final int id = await stack.insertAlarm(hour: 7, minute: 0);
      final DateTime stored = await scheduleAt(id, morning);
      await openEpisode(id, stored);
      final AlarmScheduleResult snoozed =
          await stack.coordinator.snoozeAlarm(
        alarmId: id,
        firedTriggerAt: stored,
        now: stored,
      );
      final DateTime target = (snoozed as AlarmScheduled).triggerAt;
      stack.scheduler.calls.clear();
      stack.scheduler.scheduledTriggers.clear();

      // App start / boot while the snooze waits: the stored temporary
      // trigger must survive instead of being recomputed away.
      final ReconciliationReport report =
          await stack.coordinator.reconcileSchedules(
        now: stored.add(const Duration(minutes: 1)),
      );
      expect(report.scheduled, 1);
      expect(stack.scheduler.scheduledTriggers.single, target);
      expect(
        (await stack.repository.getAlarmById(id))?.nextTriggerAt,
        target,
      );
    });

    test('open episode with a past trigger recomputes normally', () async {
      final int id = await stack.insertAlarm(hour: 7, minute: 0);
      final DateTime stored = await scheduleAt(id, morning);
      await openEpisode(id, stored);
      stack.scheduler.scheduledTriggers.clear();
      final ReconciliationReport report =
          await stack.coordinator.reconcileSchedules(
        now: DateTime(2026, 10, 8, 9, 0),
      );
      expect(report.scheduled, 1);
      expect(
        stack.scheduler.scheduledTriggers.single,
        DateTime(2026, 10, 9, 7, 0),
      );
    });

    test('stale open row over a normal trigger re-issues the same value',
        () async {
      final int id = await stack.insertAlarm(hour: 7, minute: 0);
      final DateTime stored = await scheduleAt(id, morning);
      // Simulates an edit that rewrote the trigger mid-snooze: the old
      // episode row is still open over a normal future trigger.
      await openEpisode(
        id,
        stored.subtract(const Duration(days: 1)),
        snoozeCount: 2,
        pendingTarget: stored.subtract(const Duration(days: 1)),
      );
      stack.scheduler.scheduledTriggers.clear();
      await stack.coordinator.reconcileSchedules(now: morning);
      expect(stack.scheduler.scheduledTriggers.single, stored);
      expect(
        (await stack.repository.getAlarmById(id))?.nextTriggerAt,
        stored,
      );
    });

    test('no history keeps the normal path', () async {
      final int id = await stack.insertAlarm(hour: 7, minute: 0);
      await scheduleAt(id, morning);
      stack.scheduler.scheduledTriggers.clear();
      await stack.coordinator.reconcileSchedules(now: morning);
      expect(
        stack.scheduler.scheduledTriggers.single,
        DateTime(2026, 10, 8, 7, 0),
      );
    });
  });
}
