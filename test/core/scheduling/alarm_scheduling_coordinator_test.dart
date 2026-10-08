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
  Object? isRingingError;
  final Set<int> ringingIds = <int>{};
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

  @override
  Future<bool> isRingingAlarm({required int alarmId}) async {
    if (isRingingError != null) {
      throw isRingingError!;
    }
    return ringingIds.contains(alarmId);
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

  group('reconcile after boot', () {
    test('keeps a valid future trigger', () async {
      final int id = await insertAlarm();
      await coordinator.scheduleAlarm(id, now: monday);
      final DateTime stored =
          (await alarms.getAlarmById(id))!.nextTriggerAt!;
      expect(stored, DateTime(2026, 10, 6, 7, 30));

      final ReconciliationReport report =
          await coordinator.reconcileSchedules(now: monday);

      expect(report.processed, 1);
      expect(report.scheduled, 1);
      expect(report.failed, 0);
      expect(scheduler.scheduledTriggers, <DateTime>[stored, stored]);
      expect((await alarms.getAlarmById(id))!.nextTriggerAt, stored);
    });

    test('repairs a past trigger', () async {
      final int id = await insertAlarm();
      await coordinator.scheduleAlarm(id, now: monday);
      final DateTime wednesday = DateTime(2026, 10, 7, 10, 0);

      final ReconciliationReport report =
          await coordinator.reconcileSchedules(now: wednesday);

      expect(report.scheduled, 1);
      final DateTime expected = DateTime(2026, 10, 8, 7, 30);
      expect(scheduler.scheduledTriggers.last, expected);
      expect((await alarms.getAlarmById(id))!.nextTriggerAt, expected);
    });

    test('schedules a null trigger fresh', () async {
      final int id = await insertAlarm();
      expect((await alarms.getAlarmById(id))!.nextTriggerAt, isNull);

      final ReconciliationReport report =
          await coordinator.reconcileSchedules(now: monday);

      expect(report.scheduled, 1);
      final DateTime expected = DateTime(2026, 10, 6, 7, 30);
      expect(scheduler.scheduledTriggers, <DateTime>[expected]);
      expect((await alarms.getAlarmById(id))!.nextTriggerAt, expected);
    });

    test('clears a past one-time alarm without rescheduling', () async {
      final int id = await insertAlarm(
        repeatType: RepeatType.once,
        onceDate: DateTime(2026, 10, 6),
      );
      await coordinator.scheduleAlarm(id, now: monday);

      final ReconciliationReport report = await coordinator.reconcileSchedules(
        now: DateTime(2026, 10, 7, 10, 0),
      );

      expect(report.scheduled, 0);
      expect(report.unschedulable, 1);
      expect(scheduler.scheduledIds.length, 1);
      expect((await alarms.getAlarmById(id))!.nextTriggerAt, isNull);
    });

    test('leaves a ringing one-time alarm untouched (startup never kills a ring)',
        () async {
      final int id = await insertAlarm(
        repeatType: RepeatType.once,
        onceDate: DateTime(2026, 10, 6),
      );
      await coordinator.scheduleAlarm(id, now: monday);
      final DateTime? stored =
          (await alarms.getAlarmById(id))!.nextTriggerAt;
      expect(stored, isNotNull);
      // The alarm fired and the service is ringing while the app starts.
      // (scheduleAlarm cancels before scheduling; clear that setup noise.)
      scheduler.cancelledIds.clear();
      scheduler.ringingIds.add(id);

      final ReconciliationReport report = await coordinator.reconcileSchedules(
        now: DateTime(2026, 10, 7, 10, 0),
      );

      expect(report.processed, 1);
      expect(report.scheduled, 1);
      expect(report.unschedulable, 0);
      // No cancel (which would stop the service) and no reschedule.
      expect(scheduler.cancelledIds, isEmpty);
      expect(scheduler.scheduledIds.length, 1);
      // Row untouched: the post-fire stop handoff completes it after stop.
      expect((await alarms.getAlarmById(id))!.nextTriggerAt, stored);
    });

    test('does not reschedule a ringing recurring alarm mid-ring', () async {
      final int id = await insertAlarm();
      await coordinator.scheduleAlarm(id, now: monday);
      // scheduleAlarm cancels before scheduling; clear that setup noise.
      scheduler.cancelledIds.clear();
      scheduler.ringingIds.add(id);

      final ReconciliationReport report = await coordinator.reconcileSchedules(
        now: DateTime(2026, 10, 7, 10, 0),
      );

      expect(report.scheduled, 1);
      expect(scheduler.cancelledIds, isEmpty);
      expect(scheduler.scheduledTriggers.length, 1);
    });

    test('failed ringing query counts failed without touching native state',
        () async {
      final int id = await insertAlarm();
      await coordinator.scheduleAlarm(id, now: monday);
      scheduler.calls.clear();
      scheduler.isRingingError = StateError('bridge down');

      final ReconciliationReport report =
          await coordinator.reconcileSchedules(now: monday);

      expect(report.processed, 1);
      expect(report.failed, 1);
      expect(report.scheduled, 0);
      expect(scheduler.calls, isEmpty);
    });

    test('ringing guard is selective: other alarms still reconcile', () async {
      final int ringing = await insertAlarm();
      final int idle = await insertAlarm();
      await coordinator.scheduleAlarm(ringing, now: monday);
      await coordinator.scheduleAlarm(idle, now: monday);
      scheduler.ringingIds.add(ringing);
      scheduler.cancelledIds.clear();

      final ReconciliationReport report = await coordinator.reconcileSchedules(
        now: DateTime(2026, 10, 7, 10, 0),
      );

      expect(report.processed, 2);
      expect(report.scheduled, 2);
      expect(report.failed, 0);
      expect(scheduler.cancelledIds, <int>[idle]);
    });

    test('custom alarm with past trigger chains to next selected day',
        () async {
      final int id = await insertAlarm(
        repeatDays: RepeatDays.fromDays(
          <Weekday>{Weekday.monday, Weekday.wednesday, Weekday.friday},
        ),
        repeatType: RepeatType.custom,
      );
      await coordinator.scheduleAlarm(id, now: monday);
      expect(
        scheduler.scheduledTriggers.single,
        DateTime(2026, 10, 7, 7, 30),
      );

      final ReconciliationReport report = await coordinator.reconcileSchedules(
        now: DateTime(2026, 10, 7, 10, 0),
      );

      expect(report.scheduled, 1);
      final DateTime expected = DateTime(2026, 10, 9, 7, 30);
      expect(scheduler.scheduledTriggers.last, expected);
      expect((await alarms.getAlarmById(id))!.nextTriggerAt, expected);
    });

    test('disabled alarm with stale trigger is cleared, never scheduled',
        () async {
      final int id = await insertAlarm(label: 'Gym');
      await coordinator.scheduleAlarm(id, now: monday);
      expect((await alarms.getAlarmById(id))!.nextTriggerAt, isNotNull);
      // Bypass the coordinator so the stale trigger stays behind.
      await alarms.setAlarmEnabled(id, false);

      final ReconciliationReport report =
          await coordinator.reconcileSchedules(now: monday);

      expect(report.disabledCleared, 1);
      expect(report.scheduled, 0);
      expect(scheduler.scheduledIds.length, 1);
      expect((await alarms.getAlarmById(id))!.nextTriggerAt, isNull);
    });

    test('disabled alarm drives a native cancel for stale ledger state',
        () async {
      final int id = await insertAlarm();
      await coordinator.scheduleAlarm(id, now: monday);
      await alarms.setAlarmEnabled(id, false);

      await coordinator.reconcileSchedules(now: monday);

      // cancelAlarm is what removes the native schedule + ledger entry.
      expect(scheduler.cancelledIds, contains(id));
      expect((await alarms.getAlarmById(id))!.nextTriggerAt, isNull);
    });

    test('future one-time alarm is scheduled', () async {
      final int id = await insertAlarm(
        repeatType: RepeatType.once,
        onceDate: DateTime(2026, 10, 8),
      );

      final ReconciliationReport report =
          await coordinator.reconcileSchedules(now: monday);

      expect(report.scheduled, 1);
      final DateTime expected = DateTime(2026, 10, 8, 7, 30);
      expect(scheduler.scheduledTriggers, <DateTime>[expected]);
      expect((await alarms.getAlarmById(id))!.nextTriggerAt, expected);
    });

    test('past one-time alarm is never recreated, even across passes',
        () async {
      final int id = await insertAlarm(
        repeatType: RepeatType.once,
        onceDate: DateTime(2026, 10, 6),
      );
      final DateTime ref = DateTime(2026, 10, 7, 10, 0);

      await coordinator.reconcileSchedules(now: ref);
      final ReconciliationReport second =
          await coordinator.reconcileSchedules(now: ref);

      expect(second.unschedulable, 1);
      expect(scheduler.scheduledIds, isEmpty);
      expect((await alarms.getAlarmById(id))!.nextTriggerAt, isNull);
    });

    test('reconciling twice yields the same effective state', () async {
      final int id = await insertAlarm();
      await coordinator.scheduleAlarm(id, now: monday);
      final DateTime stored =
          (await alarms.getAlarmById(id))!.nextTriggerAt!;

      await coordinator.reconcileSchedules(now: monday);
      final ReconciliationReport second =
          await coordinator.reconcileSchedules(now: monday);

      expect(second.scheduled, 1);
      expect(second.failed, 0);
      expect(scheduler.scheduledTriggers, <DateTime>[stored, stored, stored]);
      expect((await alarms.getAlarmById(id))!.nextTriggerAt, stored);
    });

    test('reconciling three times stays stable', () async {
      final int a = await insertAlarm();
      final int b = await insertAlarm(hour: 8, minute: 0);
      final DateTime expectedA = DateTime(2026, 10, 6, 7, 30);
      final DateTime expectedB = DateTime(2026, 10, 6, 8, 0);

      for (int i = 0; i < 3; i++) {
        final ReconciliationReport report =
            await coordinator.reconcileSchedules(now: monday);
        expect(report.processed, 2);
        expect(report.scheduled, 2);
        expect(report.failed, 0);
      }

      expect((await alarms.getAlarmById(a))!.nextTriggerAt, expectedA);
      expect((await alarms.getAlarmById(b))!.nextTriggerAt, expectedB);
      expect(
        scheduler.scheduledTriggers.where((DateTime t) => t == expectedA),
        hasLength(3),
      );
      expect(
        scheduler.scheduledTriggers.where((DateTime t) => t == expectedB),
        hasLength(3),
      );
    });

    test('missing native state is repaired by re-issuing the schedule',
        () async {
      final int id = await insertAlarm();
      await coordinator.scheduleAlarm(id, now: monday);
      final int before = scheduler.scheduledIds.length;

      await coordinator.reconcileSchedules(now: monday);

      // The re-issue is what recreates the wiped native schedule + ledger.
      expect(scheduler.scheduledIds.length, before + 1);
      expect(scheduler.scheduledIds.last, id);
    });

    test('valid schedule token is preserved, not rewritten', () async {
      final int id = await insertAlarm();
      await coordinator.scheduleAlarm(id, now: monday);
      final DateTime stored =
          (await alarms.getAlarmById(id))!.nextTriggerAt!;

      await coordinator.reconcileSchedules(now: monday);

      expect(scheduler.scheduledTriggers.last, stored);
      expect((await alarms.getAlarmById(id))!.nextTriggerAt, stored);
    });

    test('missing permission is reported and scheduled nothing', () async {
      scheduler.canSchedule = false;
      final int id = await insertAlarm();

      final ReconciliationReport report =
          await coordinator.reconcileSchedules(now: monday);

      expect(report.permissionMissing, 1);
      expect(report.scheduled, 0);
      expect(scheduler.scheduledIds, isEmpty);
      expect((await alarms.getAlarmById(id))!.nextTriggerAt, isNull);
    });

    test('multiple enabled alarms are all reconciled', () async {
      final int a = await insertAlarm();
      final int b = await insertAlarm(hour: 8, minute: 0);
      final int c = await insertAlarm(hour: 9, minute: 15);

      final ReconciliationReport report =
          await coordinator.reconcileSchedules(now: monday);

      expect(report.processed, 3);
      expect(report.scheduled, 3);
      expect(report.failed, 0);
      expect(
        (await alarms.getAlarmById(a))!.nextTriggerAt,
        DateTime(2026, 10, 6, 7, 30),
      );
      expect(
        (await alarms.getAlarmById(b))!.nextTriggerAt,
        DateTime(2026, 10, 6, 8, 0),
      );
      expect(
        (await alarms.getAlarmById(c))!.nextTriggerAt,
        DateTime(2026, 10, 6, 9, 15),
      );
    });

    test('mixed once/daily/custom/disabled alarms reconcile per type',
        () async {
      final int once = await insertAlarm(
        repeatType: RepeatType.once,
        onceDate: DateTime(2026, 10, 8),
      );
      final int daily = await insertAlarm();
      final int custom = await insertAlarm(
        repeatDays: RepeatDays.fromDays(<Weekday>{Weekday.friday}),
        repeatType: RepeatType.custom,
      );
      final int empty = await insertAlarm(repeatType: RepeatType.custom);
      final int off = await insertAlarm(label: 'Off');
      await coordinator.scheduleAlarm(daily, now: monday);
      await coordinator.scheduleAlarm(off, now: monday);
      await alarms.setAlarmEnabled(off, false);
      final DateTime ref = DateTime(2026, 10, 7, 10, 0);

      final ReconciliationReport report =
          await coordinator.reconcileSchedules(now: ref);

      expect(report.processed, 5);
      expect(report.scheduled, 3);
      expect(report.unschedulable, 1);
      expect(report.disabledCleared, 1);
      expect(report.failed, 0);
      expect(
        (await alarms.getAlarmById(once))!.nextTriggerAt,
        DateTime(2026, 10, 8, 7, 30),
      );
      expect(
        (await alarms.getAlarmById(daily))!.nextTriggerAt,
        DateTime(2026, 10, 8, 7, 30),
      );
      expect(
        (await alarms.getAlarmById(custom))!.nextTriggerAt,
        DateTime(2026, 10, 9, 7, 30),
      );
      expect((await alarms.getAlarmById(empty))!.nextTriggerAt, isNull);
      expect((await alarms.getAlarmById(off))!.nextTriggerAt, isNull);
    });

    test('Sunday-only alarm reconciles to Sunday', () async {
      final int id = await insertAlarm(
        repeatDays: RepeatDays.fromDays(<Weekday>{Weekday.sunday}),
        repeatType: RepeatType.custom,
      );
      final DateTime saturday = DateTime(2026, 10, 10, 10, 0);

      final ReconciliationReport report =
          await coordinator.reconcileSchedules(now: saturday);

      expect(report.scheduled, 1);
      final DateTime expected = DateTime(2026, 10, 11, 7, 30);
      expect(scheduler.scheduledTriggers, <DateTime>[expected]);
      expect((await alarms.getAlarmById(id))!.nextTriggerAt, expected);
    });

    test('scheduler failure is counted and persists no trigger', () async {
      final int id = await insertAlarm();
      scheduler.scheduleError = StateError('native exploded');

      final ReconciliationReport report =
          await coordinator.reconcileSchedules(now: monday);

      expect(report.failed, 1);
      expect(report.scheduled, 0);
      expect(scheduler.scheduledIds, isEmpty);
      expect((await alarms.getAlarmById(id))!.nextTriggerAt, isNull);
    });

    test('stale fire token stays rejected after reconciliation', () async {
      final int id = await insertAlarm();
      await coordinator.scheduleAlarm(id, now: monday);
      final DateTime old = scheduler.scheduledTriggers.single;
      await coordinator.reconcileSchedules(
        now: DateTime(2026, 10, 7, 10, 0),
      );

      final AlarmScheduleResult result = await coordinator.rescheduleAfterFire(
        alarmId: id,
        firedTriggerAt: old,
      );

      expect(result, isA<AlarmNotSchedulable>());
      expect(
        (await alarms.getAlarmById(id))!.nextTriggerAt,
        DateTime(2026, 10, 8, 7, 30),
      );
    });

    test('reconciliation leaves unrelated alarm values untouched', () async {
      final int clean = await insertAlarm(enabled: false, label: 'Keep');
      final int worker = await insertAlarm();

      await coordinator.reconcileSchedules(now: monday);

      final Alarm kept = (await alarms.getAlarmById(clean))!;
      expect(kept.enabled, isFalse);
      expect(kept.label, 'Keep');
      expect(kept.hour, 7);
      expect(kept.minute, 30);
      expect(kept.nextTriggerAt, isNull);
      expect(
        (await alarms.getAlarmById(worker))!.nextTriggerAt,
        DateTime(2026, 10, 6, 7, 30),
      );
    });

    test('empty database reconciles to an empty report', () async {
      final ReconciliationReport report =
          await coordinator.reconcileSchedules(now: monday);

      expect(report.processed, 0);
      expect(report.scheduled, 0);
      expect(report.failed, 0);
      expect(scheduler.calls, isEmpty);
    });
  });

  group('lifecycle recovery', () {
    test('clock jump forward reschedules from the new time', () async {
      final int id = await insertAlarm();
      await coordinator.scheduleAlarm(id, now: monday);
      final DateTime friday = DateTime(2026, 10, 9, 10, 0);

      final ReconciliationReport report =
          await coordinator.reconcileSchedules(now: friday);

      expect(report.scheduled, 1);
      final DateTime expected = DateTime(2026, 10, 10, 7, 30);
      expect(scheduler.scheduledTriggers.last, expected);
      expect((await alarms.getAlarmById(id))!.nextTriggerAt, expected);
    });

    test('clock jump backward recomputes, not preserves', () async {
      final int id = await insertAlarm();
      await coordinator.scheduleAlarm(id, now: DateTime(2026, 10, 9, 10, 0));
      expect(
        scheduler.scheduledTriggers.single,
        DateTime(2026, 10, 10, 7, 30),
      );

      final ReconciliationReport report = await coordinator.reconcileSchedules(
        now: DateTime(2026, 10, 7, 10, 0),
      );

      expect(report.scheduled, 1);
      final DateTime expected = DateTime(2026, 10, 8, 7, 30);
      expect(scheduler.scheduledTriggers.last, expected);
      expect((await alarms.getAlarmById(id))!.nextTriggerAt, expected);
    });

    test('one-time alarm caught by a forward jump stays completed', () async {
      final int id = await insertAlarm(
        repeatType: RepeatType.once,
        onceDate: DateTime(2026, 10, 6),
      );
      await coordinator.scheduleAlarm(id, now: monday);

      final ReconciliationReport report = await coordinator.reconcileSchedules(
        now: DateTime(2026, 10, 9, 10, 0),
      );

      expect(report.unschedulable, 1);
      expect(scheduler.scheduledIds.length, 1);
      expect((await alarms.getAlarmById(id))!.nextTriggerAt, isNull);
    });

    test('future alarm survives a forward jump unchanged', () async {
      final int id = await insertAlarm();
      await coordinator.scheduleAlarm(id, now: DateTime(2026, 10, 9, 10, 0));
      final DateTime stored =
          (await alarms.getAlarmById(id))!.nextTriggerAt!;

      final ReconciliationReport report = await coordinator.reconcileSchedules(
        now: DateTime(2026, 10, 9, 10, 0),
      );

      expect(report.scheduled, 1);
      expect(scheduler.scheduledTriggers.last, stored);
      expect((await alarms.getAlarmById(id))!.nextTriggerAt, stored);
    });

    test('date change across midnight schedules the new day', () async {
      final int id = await insertAlarm();

      final ReconciliationReport report = await coordinator.reconcileSchedules(
        now: DateTime(2026, 10, 5, 23, 59),
      );

      expect(report.scheduled, 1);
      final DateTime expected = DateTime(2026, 10, 6, 7, 30);
      expect(scheduler.scheduledTriggers, <DateTime>[expected]);
      expect((await alarms.getAlarmById(id))!.nextTriggerAt, expected);
    });

    test('date change moves custom alarms to the next selected day', () async {
      final int id = await insertAlarm(
        repeatDays: RepeatDays.fromDays(
          <Weekday>{Weekday.monday, Weekday.wednesday, Weekday.friday},
        ),
        repeatType: RepeatType.custom,
      );

      final ReconciliationReport report = await coordinator.reconcileSchedules(
        now: DateTime(2026, 10, 6, 12, 0),
      );

      expect(report.scheduled, 1);
      final DateTime expected = DateTime(2026, 10, 7, 7, 30);
      expect(scheduler.scheduledTriggers, <DateTime>[expected]);
      expect((await alarms.getAlarmById(id))!.nextTriggerAt, expected);
    });

    test('date change keeps a same-day one-time alarm', () async {
      final int id = await insertAlarm(
        repeatType: RepeatType.once,
        onceDate: DateTime(2026, 10, 7),
      );

      final ReconciliationReport report = await coordinator.reconcileSchedules(
        now: DateTime(2026, 10, 6, 10, 0),
      );

      expect(report.scheduled, 1);
      final DateTime expected = DateTime(2026, 10, 7, 7, 30);
      expect(scheduler.scheduledTriggers, <DateTime>[expected]);
      expect((await alarms.getAlarmById(id))!.nextTriggerAt, expected);
    });

    test('date change clears disabled alarms with stale triggers', () async {
      final int id = await insertAlarm();
      await coordinator.scheduleAlarm(id, now: monday);
      await alarms.setAlarmEnabled(id, false);

      final ReconciliationReport report = await coordinator.reconcileSchedules(
        now: DateTime(2026, 10, 6, 0, 1),
      );

      expect(report.disabledCleared, 1);
      expect(scheduler.scheduledIds.length, 1);
      expect((await alarms.getAlarmById(id))!.nextTriggerAt, isNull);
    });

    test('daily alarm tracks wall time across a timezone shift', () async {
      final int id = await insertAlarm();
      await coordinator.reconcileSchedules(
        now: DateTime(2026, 10, 5, 6, 0),
      );
      expect(
        (await alarms.getAlarmById(id))!.nextTriggerAt,
        DateTime(2026, 10, 5, 7, 30),
      );

      // Wall clock now reads 08:00 in the new zone: the 07:30 definition
      // moved to the next day, not by a fixed offset.
      final ReconciliationReport report = await coordinator.reconcileSchedules(
        now: DateTime(2026, 10, 5, 8, 0),
      );

      expect(report.scheduled, 1);
      final DateTime expected = DateTime(2026, 10, 6, 7, 30);
      expect(scheduler.scheduledTriggers.last, expected);
      expect((await alarms.getAlarmById(id))!.nextTriggerAt, expected);
    });

    test('custom alarm tracks wall time across a timezone shift', () async {
      final int id = await insertAlarm(
        repeatDays: RepeatDays.fromDays(<Weekday>{Weekday.friday}),
        repeatType: RepeatType.custom,
      );
      await coordinator.reconcileSchedules(
        now: DateTime(2026, 10, 9, 6, 0),
      );
      expect(
        (await alarms.getAlarmById(id))!.nextTriggerAt,
        DateTime(2026, 10, 9, 7, 30),
      );

      final ReconciliationReport report = await coordinator.reconcileSchedules(
        now: DateTime(2026, 10, 9, 8, 0),
      );

      expect(report.scheduled, 1);
      final DateTime expected = DateTime(2026, 10, 16, 7, 30);
      expect(scheduler.scheduledTriggers.last, expected);
      expect((await alarms.getAlarmById(id))!.nextTriggerAt, expected);
    });

    test('permission restoration schedules previously skipped alarms',
        () async {
      scheduler.canSchedule = false;
      final int id = await insertAlarm();
      final ReconciliationReport blocked =
          await coordinator.reconcileSchedules(now: monday);
      expect(blocked.permissionMissing, 1);
      expect((await alarms.getAlarmById(id))!.nextTriggerAt, isNull);

      scheduler.canSchedule = true;
      final ReconciliationReport restored =
          await coordinator.reconcileSchedules(now: monday);

      expect(restored.permissionMissing, 0);
      expect(restored.scheduled, 1);
      final DateTime expected = DateTime(2026, 10, 6, 7, 30);
      expect(scheduler.scheduledTriggers, <DateTime>[expected]);
      expect((await alarms.getAlarmById(id))!.nextTriggerAt, expected);
    });

    test('package update restores the mixed set without resurrection',
        () async {
      final int daily = await insertAlarm();
      final int custom = await insertAlarm(
        repeatDays: RepeatDays.fromDays(<Weekday>{Weekday.friday}),
        repeatType: RepeatType.custom,
      );
      final int oncePast = await insertAlarm(
        repeatType: RepeatType.once,
        onceDate: DateTime(2026, 10, 6),
      );
      final int off = await insertAlarm();
      await coordinator.scheduleAlarm(daily, now: monday);
      await coordinator.scheduleAlarm(off, now: monday);
      await alarms.setAlarmEnabled(off, false);
      final DateTime ref = DateTime(2026, 10, 8, 10, 0);

      final ReconciliationReport report =
          await coordinator.reconcileSchedules(now: ref);

      expect(report.processed, 4);
      expect(report.scheduled, 2);
      expect(report.unschedulable, 1);
      expect(report.disabledCleared, 1);
      expect(report.failed, 0);
      expect(
        (await alarms.getAlarmById(daily))!.nextTriggerAt,
        DateTime(2026, 10, 9, 7, 30),
      );
      expect(
        (await alarms.getAlarmById(custom))!.nextTriggerAt,
        DateTime(2026, 10, 9, 7, 30),
      );
      expect((await alarms.getAlarmById(oncePast))!.nextTriggerAt, isNull);
      expect((await alarms.getAlarmById(off))!.nextTriggerAt, isNull);
      expect(
        scheduler.scheduledIds.where((int id) => id == daily),
        hasLength(2),
      );
    });

    test('advancing reconciles chain forward with no duplicates', () async {
      final int id = await insertAlarm();
      await coordinator.reconcileSchedules(now: monday);
      await coordinator.reconcileSchedules(
        now: DateTime(2026, 10, 6, 10, 0),
      );
      await coordinator.reconcileSchedules(
        now: DateTime(2026, 10, 7, 10, 0),
      );

      expect(scheduler.scheduledTriggers, <DateTime>[
        DateTime(2026, 10, 6, 7, 30),
        DateTime(2026, 10, 7, 7, 30),
        DateTime(2026, 10, 8, 7, 30),
      ]);
      expect(
        (await alarms.getAlarmById(id))!.nextTriggerAt,
        DateTime(2026, 10, 8, 7, 30),
      );
    });

    test('unknown tokens rejected, valid token chains after reconcile',
        () async {
      final int id = await insertAlarm();
      await coordinator.scheduleAlarm(id, now: monday);
      await coordinator.reconcileSchedules(
        now: DateTime(2026, 10, 7, 10, 0),
      );
      final DateTime stored =
          (await alarms.getAlarmById(id))!.nextTriggerAt!;
      expect(stored, DateTime(2026, 10, 8, 7, 30));

      final AlarmScheduleResult rejected =
          await coordinator.rescheduleAfterFire(
        alarmId: id,
        firedTriggerAt: DateTime(2026, 10, 9, 7, 30),
      );
      expect(rejected, isA<AlarmNotSchedulable>());
      expect((await alarms.getAlarmById(id))!.nextTriggerAt, stored);

      final AlarmScheduleResult chained =
          await coordinator.rescheduleAfterFire(
        alarmId: id,
        firedTriggerAt: stored,
      );
      final AlarmScheduled scheduled = chained as AlarmScheduled;
      expect(scheduled.triggerAt, DateTime(2026, 10, 9, 7, 30));
      expect(
        (await alarms.getAlarmById(id))!.nextTriggerAt,
        scheduled.triggerAt,
      );
    });

    test('mixed set under a backward jump recomputes every alarm', () async {
      final int daily = await insertAlarm();
      final int custom = await insertAlarm(
        repeatDays: RepeatDays.fromDays(
          <Weekday>{Weekday.monday, Weekday.wednesday, Weekday.friday},
        ),
        repeatType: RepeatType.custom,
      );
      final int once = await insertAlarm(
        repeatType: RepeatType.once,
        onceDate: DateTime(2026, 10, 8),
      );
      final int off = await insertAlarm(label: 'Off');
      await coordinator.scheduleAlarm(daily, now: DateTime(2026, 10, 9, 10, 0));
      await coordinator.scheduleAlarm(off, now: DateTime(2026, 10, 9, 10, 0));
      await alarms.setAlarmEnabled(off, false);

      final ReconciliationReport report = await coordinator.reconcileSchedules(
        now: DateTime(2026, 10, 7, 10, 0),
      );

      expect(report.processed, 4);
      expect(report.scheduled, 3);
      expect(report.disabledCleared, 1);
      expect(report.failed, 0);
      expect(
        (await alarms.getAlarmById(daily))!.nextTriggerAt,
        DateTime(2026, 10, 8, 7, 30),
      );
      expect(
        (await alarms.getAlarmById(custom))!.nextTriggerAt,
        DateTime(2026, 10, 9, 7, 30),
      );
      expect(
        (await alarms.getAlarmById(once))!.nextTriggerAt,
        DateTime(2026, 10, 8, 7, 30),
      );
      expect((await alarms.getAlarmById(off))!.nextTriggerAt, isNull);
    });
  });
}
