import 'package:alarmx/core/alarms/alarm_fire_config.dart';
import 'package:alarmx/core/alarms/native_alarm_scheduler.dart';
import 'package:alarmx/core/database/database.dart';
import 'package:alarmx/core/models/models.dart';
import 'package:alarmx/core/repositories/alarm_repository.dart';
import 'package:alarmx/core/scheduling/alarm_schedule_result.dart';
import 'package:alarmx/core/scheduling/alarm_scheduling_coordinator.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

// Coordinator tests: real in-memory repository + fake native scheduler.
// No device, no channels, deterministic pinned `now` (Mon 2026-10-05 10:00).

/// Records native calls and replays scripted failures.
class FakeNativeAlarmScheduler implements NativeAlarmScheduler {
  FakeNativeAlarmScheduler({this.canSchedule = true});

  bool canSchedule;
  Object? scheduleError;
  Object? cancelError;
  Object? checkError;
  final List<String> calls = <String>[];
  final List<int> scheduledIds = <int>[];
  final List<DateTime> scheduledTriggers = <DateTime>[];
  final List<AlarmFireConfig?> scheduledConfigs = <AlarmFireConfig?>[];
  final List<int> cancelledIds = <int>[];

  @override
  Future<void> scheduleExactAlarm({
    required int alarmId,
    required DateTime triggerAt,
    AlarmFireConfig? fireConfig,
  }) async {
    calls.add('schedule:$alarmId');
    if (scheduleError != null) {
      throw scheduleError!;
    }
    scheduledIds.add(alarmId);
    scheduledTriggers.add(triggerAt);
    scheduledConfigs.add(fireConfig);
  }

  @override
  Future<void> cancelAlarm({required int alarmId}) async {
    calls.add('cancel:$alarmId');
    if (cancelError != null) {
      throw cancelError!;
    }
    cancelledIds.add(alarmId);
  }

  @override
  Future<bool> canScheduleExactAlarms() async {
    if (checkError != null) {
      throw checkError!;
    }
    return canSchedule;
  }
}

void main() {
  late AppDatabase db;
  late AlarmRepository alarms;
  late FakeNativeAlarmScheduler scheduler;
  late AlarmSchedulingCoordinator coordinator;

  final DateTime monday = DateTime(2026, 10, 5, 10, 0);

  setUp(() {
    db = AppDatabase.connect(NativeDatabase.memory());
    alarms = DriftAlarmRepository(db.alarmDao);
    scheduler = FakeNativeAlarmScheduler();
    coordinator = AlarmSchedulingCoordinator(
      repository: alarms,
      scheduler: scheduler,
    );
  });

  tearDown(() async {
    await db.close();
  });

  Future<int> insertAlarm({
    int hour = 7,
    int minute = 30,
    bool enabled = true,
    String? label,
    bool vibrationEnabled = true,
    RepeatType repeatType = RepeatType.daily,
    DateTime? onceDate,
    RepeatDays? repeatDays,
  }) {
    return alarms.createAlarm(
      AlarmsCompanion(
        hour: Value(hour),
        minute: Value(minute),
        enabled: Value(enabled),
        label: Value(label),
        vibrationEnabled: Value(vibrationEnabled),
        repeatType: Value(repeatType.dbValue),
        onceDate: Value(onceDate),
        repeatDays: Value(repeatDays?.mask),
      ),
    );
  }

  group('schedule', () {
    test('schedules an enabled one-time alarm and persists the trigger',
        () async {
      final int id = await insertAlarm(
        repeatType: RepeatType.once,
        onceDate: DateTime(2026, 10, 6),
      );
      final AlarmScheduleResult result =
          await coordinator.scheduleAlarm(id, now: monday);

      final AlarmScheduled scheduled = result as AlarmScheduled;
      final DateTime expected = DateTime(2026, 10, 6, 7, 30);
      expect(scheduled.triggerAt, expected);
      expect(scheduler.scheduledIds, <int>[id]);
      expect(scheduler.scheduledTriggers, <DateTime>[expected]);
      expect((await alarms.getAlarmById(id))!.nextTriggerAt, expected);
    });

    test('schedules a daily alarm for tomorrow when today passed', () async {
      final int id = await insertAlarm();
      final AlarmScheduleResult result =
          await coordinator.scheduleAlarm(id, now: monday);

      final AlarmScheduled scheduled = result as AlarmScheduled;
      expect(scheduled.triggerAt, DateTime(2026, 10, 6, 7, 30));
      expect(scheduler.scheduledIds, <int>[id]);
    });

    test('schedules a selected-days alarm on the next selected day',
        () async {
      final int id = await insertAlarm(
        repeatType: RepeatType.custom,
        repeatDays: RepeatDays.fromDays(
          <Weekday>{Weekday.wednesday, Weekday.friday},
        ),
      );
      final AlarmScheduleResult result =
          await coordinator.scheduleAlarm(id, now: monday);

      final AlarmScheduled scheduled = result as AlarmScheduled;
      expect(scheduled.triggerAt, DateTime(2026, 10, 7, 7, 30));
      expect(scheduler.scheduledIds, <int>[id]);
    });

    test('past one-time alarm is not scheduled and strays are cancelled',
        () async {
      final int id = await insertAlarm(
        repeatType: RepeatType.once,
        onceDate: DateTime(2026, 10, 4),
      );
      final AlarmScheduleResult result =
          await coordinator.scheduleAlarm(id, now: monday);

      final AlarmNotSchedulable unschedulable =
          result as AlarmNotSchedulable;
      expect(unschedulable.reason, isNotEmpty);
      expect(scheduler.scheduledIds, isEmpty);
      expect(scheduler.cancelledIds, <int>[id]);
      expect((await alarms.getAlarmById(id))!.nextTriggerAt, isNull);
    });

    test('disabled alarm is not scheduled', () async {
      final int id = await insertAlarm(enabled: false);
      final AlarmScheduleResult result =
          await coordinator.scheduleAlarm(id, now: monday);

      expect(result, isA<AlarmDisabled>());
      expect(scheduler.scheduledIds, isEmpty);
      expect((await alarms.getAlarmById(id))!.nextTriggerAt, isNull);
    });

    test('missing alarm fails without touching the native layer', () async {
      final AlarmScheduleResult result =
          await coordinator.scheduleAlarm(999, now: monday);

      final AlarmScheduleFailed failed = result as AlarmScheduleFailed;
      expect(failed.error, isA<StateError>());
      expect(scheduler.calls, isEmpty);
    });

    test('uses the real database id, not a hardcoded one', () async {
      await insertAlarm();
      final int secondId = await insertAlarm(hour: 8);
      final AlarmScheduleResult result =
          await coordinator.scheduleAlarm(secondId, now: monday);

      expect(result, isA<AlarmScheduled>());
      expect(scheduler.scheduledIds, <int>[secondId]);
      expect(
        (await alarms.getAlarmById(secondId))!.nextTriggerAt,
        DateTime(2026, 10, 6, 8, 30),
      );
    });

    test('calculated trigger reaches the scheduler unchanged', () async {
      final int id = await insertAlarm(
        repeatType: RepeatType.custom,
        repeatDays: RepeatDays.fromDays(<Weekday>{Weekday.tuesday}),
      );
      final AlarmScheduleResult result =
          await coordinator.scheduleAlarm(id, now: monday);

      final AlarmScheduled scheduled = result as AlarmScheduled;
      final DateTime expected = DateTime(2026, 10, 6, 7, 30);
      expect(scheduled.triggerAt, expected);
      expect(scheduler.scheduledTriggers, hasLength(1));
      final DateTime actual = scheduler.scheduledTriggers.single;
      expect(actual, expected);
      expect(actual.millisecondsSinceEpoch, expected.millisecondsSinceEpoch);
      expect(actual.isUtc, expected.isUtc);
    });
  });

  group('failures', () {
    test('scheduler failure is reported and stored state stays clean',
        () async {
      final StateError error = StateError('native exploded');
      scheduler.scheduleError = error;
      final int id = await insertAlarm();
      final AlarmScheduleResult result =
          await coordinator.scheduleAlarm(id, now: monday);

      final AlarmScheduleFailed failed = result as AlarmScheduleFailed;
      expect(failed.error, same(error));
      expect(failed.scheduledButNotPersisted, isNull);
      expect(scheduler.scheduledIds, isEmpty);
      expect(scheduler.calls, <String>['cancel:$id', 'schedule:$id']);
      expect((await alarms.getAlarmById(id))!.nextTriggerAt, isNull);
    });

    test('missing exact-alarm permission is reported distinctly', () async {
      scheduler.canSchedule = false;
      final int id = await insertAlarm();
      final AlarmScheduleResult result =
          await coordinator.scheduleAlarm(id, now: monday);

      expect(result, isA<AlarmPermissionMissing>());
      expect(scheduler.scheduledIds, isEmpty);
      expect(scheduler.cancelledIds, <int>[id]);
      expect((await alarms.getAlarmById(id))!.nextTriggerAt, isNull);
    });

    test('permission check failure is reported', () async {
      final StateError error = StateError('check exploded');
      scheduler.checkError = error;
      final int id = await insertAlarm();
      final AlarmScheduleResult result =
          await coordinator.scheduleAlarm(id, now: monday);

      final AlarmScheduleFailed failed = result as AlarmScheduleFailed;
      expect(failed.error, same(error));
      expect(scheduler.scheduledIds, isEmpty);
    });
  });

  group('reschedule', () {
    test('cancels the old schedule before scheduling the new one', () async {
      final int id = await insertAlarm();
      final AlarmScheduleResult result =
          await coordinator.rescheduleAlarm(id, now: monday);

      expect(result, isA<AlarmScheduled>());
      expect(scheduler.calls, <String>['cancel:$id', 'schedule:$id']);
      expect(
        (await alarms.getAlarmById(id))!.nextTriggerAt,
        DateTime(2026, 10, 6, 7, 30),
      );
    });
  });

  group('enable', () {
    test('enable marks the alarm enabled and schedules it', () async {
      final int id = await insertAlarm(enabled: false);
      final AlarmScheduleResult result =
          await coordinator.enableAlarm(id, now: monday);

      expect(result, isA<AlarmScheduled>());
      expect((await alarms.getAlarmById(id))!.enabled, isTrue);
      expect(scheduler.scheduledIds, <int>[id]);
    });

    test('enable keeps desired state when permission is missing', () async {
      scheduler.canSchedule = false;
      final int id = await insertAlarm(enabled: false);
      final AlarmScheduleResult result =
          await coordinator.enableAlarm(id, now: monday);

      expect(result, isA<AlarmPermissionMissing>());
      expect((await alarms.getAlarmById(id))!.enabled, isTrue);
      expect((await alarms.getAlarmById(id))!.nextTriggerAt, isNull);
    });

    test('enable on a missing alarm fails', () async {
      final AlarmScheduleResult result =
          await coordinator.enableAlarm(999, now: monday);

      final AlarmScheduleFailed failed = result as AlarmScheduleFailed;
      expect(failed.error, isA<StateError>());
      expect(scheduler.calls, isEmpty);
    });
  });

  group('disable and cancel', () {
    test('disable flips state, cancels native, clears the trigger', () async {
      final int id = await insertAlarm();
      await coordinator.scheduleAlarm(id, now: monday);
      expect((await alarms.getAlarmById(id))!.nextTriggerAt, isNotNull);

      await coordinator.disableAlarm(id);

      expect((await alarms.getAlarmById(id))!.enabled, isFalse);
      expect(scheduler.cancelledIds, contains(id));
      expect((await alarms.getAlarmById(id))!.nextTriggerAt, isNull);
    });

    test('cancel keeps the record but clears native and trigger', () async {
      final int id = await insertAlarm();
      await coordinator.scheduleAlarm(id, now: monday);

      await coordinator.cancelAlarm(id);

      expect(await alarms.getAlarmById(id), isNotNull);
      expect(scheduler.cancelledIds, contains(id));
      expect((await alarms.getAlarmById(id))!.nextTriggerAt, isNull);
    });

    test('cancel and disable on missing ids complete silently', () async {
      await coordinator.cancelAlarm(999);
      await coordinator.disableAlarm(999);
      expect(scheduler.cancelledIds, <int>[999, 999]);
    });

    test('cancel propagates scheduler errors', () async {
      final StateError error = StateError('cancel exploded');
      scheduler.cancelError = error;
      final int id = await insertAlarm();

      await expectLater(coordinator.cancelAlarm(id), throwsA(same(error)));
    });
  });

  group('fire config', () {
    test('passes the persisted label and vibration flag to native', () async {
      final int id = await insertAlarm(
        label: 'Gym',
        vibrationEnabled: false,
        repeatType: RepeatType.once,
        onceDate: DateTime(2026, 10, 6),
      );

      await coordinator.scheduleAlarm(id, now: monday);

      final AlarmFireConfig config = scheduler.scheduledConfigs.single!;
      expect(config.label, 'Gym');
      expect(config.vibrationEnabled, isFalse);
    });

    test('passes null label with default vibration when unset', () async {
      final int id = await insertAlarm(
        repeatType: RepeatType.once,
        onceDate: DateTime(2026, 10, 6),
      );

      await coordinator.scheduleAlarm(id, now: monday);

      final AlarmFireConfig config = scheduler.scheduledConfigs.single!;
      expect(config.label, isNull);
      expect(config.vibrationEnabled, isTrue);
    });
  });

  group('post-fire rescheduling', () {
    test('once alarm completes without scheduling again', () async {
      final int id = await insertAlarm(
        repeatType: RepeatType.once,
        onceDate: DateTime(2026, 10, 6),
      );
      await coordinator.scheduleAlarm(id, now: monday);
      final DateTime fired = scheduler.scheduledTriggers.single;

      final AlarmScheduleResult result = await coordinator.rescheduleAfterFire(
        alarmId: id,
        firedTriggerAt: fired,
      );

      expect(result, isA<AlarmNotSchedulable>());
      expect(scheduler.scheduledIds, <int>[id]);
      expect((await alarms.getAlarmById(id))!.nextTriggerAt, isNull);
    });

    test('daily alarm chains to tomorrow', () async {
      final int id = await insertAlarm();
      await coordinator.scheduleAlarm(id, now: monday);
      final DateTime fired = scheduler.scheduledTriggers.single;
      expect(fired, DateTime(2026, 10, 6, 7, 30));

      final AlarmScheduleResult result = await coordinator.rescheduleAfterFire(
        alarmId: id,
        firedTriggerAt: fired,
      );

      final AlarmScheduled scheduled = result as AlarmScheduled;
      expect(scheduled.triggerAt, DateTime(2026, 10, 7, 7, 30));
      expect(scheduler.scheduledTriggers.last, scheduled.triggerAt);
      expect(
        (await alarms.getAlarmById(id))!.nextTriggerAt,
        scheduled.triggerAt,
      );
    });

    test('custom alarm chains to the next selected weekday', () async {
      final int id = await insertAlarm(
        repeatDays: RepeatDays.fromDays(
          <Weekday>{Weekday.monday, Weekday.wednesday, Weekday.friday},
        ),
        repeatType: RepeatType.custom,
      );
      await coordinator.scheduleAlarm(id, now: monday);
      // Monday 07:30 already passed at 10:00 -> Wednesday.
      expect(
        scheduler.scheduledTriggers.single,
        DateTime(2026, 10, 7, 7, 30),
      );

      final AlarmScheduleResult result = await coordinator.rescheduleAfterFire(
        alarmId: id,
        firedTriggerAt: DateTime(2026, 10, 7, 7, 30),
      );

      final AlarmScheduled scheduled = result as AlarmScheduled;
      expect(scheduled.triggerAt, DateTime(2026, 10, 9, 7, 30));
      expect(
        (await alarms.getAlarmById(id))!.nextTriggerAt,
        scheduled.triggerAt,
      );
    });

    test('custom Friday fire wraps to Monday', () async {
      final DateTime thursday = DateTime(2026, 10, 8, 10, 0);
      final int id = await insertAlarm(
        repeatDays: RepeatDays.fromDays(
          <Weekday>{Weekday.monday, Weekday.friday},
        ),
        repeatType: RepeatType.custom,
      );
      await coordinator.scheduleAlarm(id, now: thursday);
      expect(
        scheduler.scheduledTriggers.single,
        DateTime(2026, 10, 9, 7, 30),
      );

      final AlarmScheduleResult result = await coordinator.rescheduleAfterFire(
        alarmId: id,
        firedTriggerAt: DateTime(2026, 10, 9, 7, 30),
      );

      final AlarmScheduled scheduled = result as AlarmScheduled;
      expect(scheduled.triggerAt, DateTime(2026, 10, 12, 7, 30));
      expect(
        (await alarms.getAlarmById(id))!.nextTriggerAt,
        scheduled.triggerAt,
      );
    });

    test('custom alarm with today passed chains a week out', () async {
      final int id = await insertAlarm(
        repeatDays: RepeatDays.fromDays(<Weekday>{Weekday.monday}),
        repeatType: RepeatType.custom,
      );
      await coordinator.scheduleAlarm(id, now: monday);
      // Monday 07:30 passed -> next Monday.
      expect(
        scheduler.scheduledTriggers.single,
        DateTime(2026, 10, 12, 7, 30),
      );

      final AlarmScheduleResult result = await coordinator.rescheduleAfterFire(
        alarmId: id,
        firedTriggerAt: DateTime(2026, 10, 12, 7, 30),
      );

      final AlarmScheduled scheduled = result as AlarmScheduled;
      expect(scheduled.triggerAt, DateTime(2026, 10, 19, 7, 30));
      expect(
        (await alarms.getAlarmById(id))!.nextTriggerAt,
        scheduled.triggerAt,
      );
    });

    test('stale fired trigger is rejected without touching state', () async {
      final int id = await insertAlarm();
      await coordinator.scheduleAlarm(id, now: monday);
      final DateTime first = scheduler.scheduledTriggers.single;
      // Alarm re-scheduled (e.g. edited) before the old fire is handled.
      await coordinator.scheduleAlarm(id, now: first);
      final DateTime second = scheduler.scheduledTriggers.last;
      expect(second.isAfter(first), isTrue);

      final AlarmScheduleResult result = await coordinator.rescheduleAfterFire(
        alarmId: id,
        firedTriggerAt: first,
      );

      expect(result, isA<AlarmNotSchedulable>());
      expect(scheduler.scheduledIds.length, 2);
      expect((await alarms.getAlarmById(id))!.nextTriggerAt, second);
    });

    test('duplicate post-fire handling schedules only once', () async {
      final int id = await insertAlarm();
      await coordinator.scheduleAlarm(id, now: monday);
      final DateTime fired = scheduler.scheduledTriggers.single;

      final AlarmScheduleResult firstResult =
          await coordinator.rescheduleAfterFire(
        alarmId: id,
        firedTriggerAt: fired,
      );
      final AlarmScheduleResult secondResult =
          await coordinator.rescheduleAfterFire(
        alarmId: id,
        firedTriggerAt: fired,
      );

      expect(firstResult, isA<AlarmScheduled>());
      expect(secondResult, isA<AlarmNotSchedulable>());
      expect(scheduler.scheduledTriggers.length, 2);
      expect(
        (await alarms.getAlarmById(id))!.nextTriggerAt,
        scheduler.scheduledTriggers.last,
      );
    });

    test('disabled alarm does not reschedule after fire', () async {
      final int id = await insertAlarm();
      await coordinator.scheduleAlarm(id, now: monday);
      final DateTime fired = scheduler.scheduledTriggers.single;
      await coordinator.disableAlarm(id);

      final AlarmScheduleResult result = await coordinator.rescheduleAfterFire(
        alarmId: id,
        firedTriggerAt: fired,
      );

      expect(result, isA<AlarmDisabled>());
      expect(scheduler.scheduledIds.length, 1);
      expect((await alarms.getAlarmById(id))!.nextTriggerAt, isNull);
    });

    test('cancelled alarm does not reschedule after fire', () async {
      final int id = await insertAlarm();
      await coordinator.scheduleAlarm(id, now: monday);
      final DateTime fired = scheduler.scheduledTriggers.single;
      await coordinator.cancelAlarm(id);

      final AlarmScheduleResult result = await coordinator.rescheduleAfterFire(
        alarmId: id,
        firedTriggerAt: fired,
      );

      expect(result, isA<AlarmNotSchedulable>());
      expect(scheduler.scheduledIds.length, 1);
      expect((await alarms.getAlarmById(id))!.nextTriggerAt, isNull);
    });

    test('scheduler failure clears instead of persisting a false trigger',
        () async {
      final int id = await insertAlarm();
      await coordinator.scheduleAlarm(id, now: monday);
      final DateTime fired = scheduler.scheduledTriggers.single;
      scheduler.scheduleError = StateError('native exploded');

      final AlarmScheduleResult result = await coordinator.rescheduleAfterFire(
        alarmId: id,
        firedTriggerAt: fired,
      );

      expect(result, isA<AlarmScheduleFailed>());
      expect((await alarms.getAlarmById(id))!.nextTriggerAt, isNull);
    });

    test('post-fire on a missing alarm fails', () async {
      final AlarmScheduleResult result = await coordinator.rescheduleAfterFire(
        alarmId: 999,
        firedTriggerAt: monday,
      );

      final AlarmScheduleFailed failed = result as AlarmScheduleFailed;
      expect(failed.error, isA<StateError>());
      expect(scheduler.calls, isEmpty);
    });
  });
}
