import 'package:alarmx/core/alarms/alarm_controller.dart';
import 'package:alarmx/core/database/database.dart';
import 'package:alarmx/core/models/models.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';

import '../../support/test_doubles.dart';

// Controller tests: real in-memory repository + real coordinator + fake
// native scheduler. Deterministic by construction: daily alarms always
// have an occurrence, fixed past/future dates pin the once cases.

void main() {
  late TestStack stack;

  setUp(() {
    stack = TestStack();
  });

  tearDown(() async {
    await stack.close();
  });

  AlarmsCompanion dailyCompanion({
    int hour = 7,
    int minute = 30,
    String? label,
    bool enabled = true,
  }) {
    return AlarmsCompanion.insert(
      hour: hour,
      minute: minute,
      label: Value(label),
      enabled: Value(enabled),
      repeatType: Value(RepeatType.daily.dbValue),
    );
  }

  group('watchAlarms / getAlarmById', () {
    test('watchAlarms emits inserted rows', () async {
      final Future<List<Alarm>> first = stack.controller.watchAlarms().first;
      await stack.insertAlarm(label: 'Work');
      final List<Alarm> alarms = await first;
      expect(alarms, hasLength(1));
      expect(alarms.single.label, 'Work');
    });

    test('getAlarmById hits and misses', () async {
      final int id = await stack.insertAlarm();
      expect((await stack.controller.getAlarmById(id))?.id, id);
      expect(await stack.controller.getAlarmById(id + 1), isNull);
    });
  });

  group('createAlarm', () {
    test('create result carries the new alarm id', () async {
      final AlarmUiResult result =
          await stack.controller.createAlarm(dailyCompanion());

      expect(result.persisted, isTrue);
      final List<Alarm> alarms = await stack.repository.getAlarms();
      expect(alarms, hasLength(1));
      expect(result.alarmId, alarms.single.id);
    });

    test('daily alarm is saved, scheduled and reported', () async {
      final AlarmUiResult result =
          await stack.controller.createAlarm(dailyCompanion(label: 'Work'));

      expect(result.ok, isTrue);
      expect(result.persisted, isTrue);
      expect(result.messageKey, 'msgAlarmSaved');

      final List<Alarm> alarms = await stack.repository.getAlarms();
      expect(alarms, hasLength(1));
      expect(alarms.single.nextTriggerAt, isNotNull);
      // Coordinator path proof: cancel-before-schedule, frozen fire config.
      expect(stack.scheduler.calls, <String>['cancel:1', 'schedule:1']);
      expect(stack.scheduler.scheduledTriggers.single,
          alarms.single.nextTriggerAt);
      expect(stack.scheduler.scheduledConfigs.single?.label, 'Work');
    });

    test('disabled alarm is saved without a schedule', () async {
      final AlarmUiResult result = await stack.controller.createAlarm(
        dailyCompanion(enabled: false),
      );

      expect(result.ok, isTrue);
      expect(result.persisted, isTrue);
      expect(stack.scheduler.scheduledIds, isEmpty);
      final Alarm? stored = await stack.repository.getAlarmById(1);
      expect(stored?.enabled, isFalse);
      expect(stored?.nextTriggerAt, isNull);
    });

    test('past one-time alarm is saved but honestly unscheduled', () async {
      final AlarmUiResult result = await stack.controller.createAlarm(
        AlarmsCompanion.insert(
          hour: 7,
          minute: 30,
          repeatType: Value(RepeatType.once.dbValue),
          onceDate: Value(DateTime(2000, 1, 1)),
        ),
      );

      expect(result.ok, isFalse);
      expect(result.persisted, isTrue);
      expect(result.messageKey, 'msgNotSchedulable');
      expect(stack.scheduler.scheduledIds, isEmpty);
      expect((await stack.repository.getAlarms()), hasLength(1));
    });

    test('missing permission keeps desired state, reports the gap', () async {
      stack.scheduler.canSchedule = false;
      final AlarmUiResult result =
          await stack.controller.createAlarm(dailyCompanion());

      expect(result.ok, isFalse);
      expect(result.persisted, isTrue);
      expect(result.messageKey, 'msgNoPermission');
      final Alarm? stored = await stack.repository.getAlarmById(1);
      expect(stored?.enabled, isTrue);
      expect(stored?.nextTriggerAt, isNull);
    });

    test('scheduler failure is reported, never claimed', () async {
      stack.scheduler.scheduleError = StateError('bridge down');
      final AlarmUiResult result =
          await stack.controller.createAlarm(dailyCompanion());

      expect(result.ok, isFalse);
      expect(result.persisted, isTrue);
      expect(result.messageKey, 'msgScheduleFailed');
      final Alarm? stored = await stack.repository.getAlarmById(1);
      expect(stored?.nextTriggerAt, isNull);
    });
  });

  group('updateAlarm', () {
    test('update result carries the row id', () async {
      final int id = await stack.insertAlarm();
      final Alarm? current = await stack.repository.getAlarmById(id);
      final AlarmUiResult result =
          await stack.controller.updateAlarm(current!);

      expect(result.persisted, isTrue);
      expect(result.alarmId, id);
    });

    test('missing-row result carries no id', () async {
      final int id = await stack.insertAlarm();
      final Alarm? current = await stack.repository.getAlarmById(id);
      final AlarmUiResult result = await stack.controller.updateAlarm(
        current!.copyWith(id: id + 100),
      );

      expect(result.persisted, isFalse);
      expect(result.alarmId, isNull);
    });

    test('edits reschedule through the coordinator', () async {
      final int id = await stack.insertAlarm(hour: 7);
      await stack.coordinator.scheduleAlarm(id);
      stack.scheduler.calls.clear();
      stack.scheduler.scheduledTriggers.clear();

      final Alarm? current = await stack.repository.getAlarmById(id);
      final AlarmUiResult result = await stack.controller.updateAlarm(
        current!.copyWith(hour: 8),
      );

      expect(result.ok, isTrue);
      expect(result.messageKey, 'msgAlarmUpdated');
      expect(stack.scheduler.calls, <String>['cancel:$id', 'schedule:$id']);
      final DateTime trigger = stack.scheduler.scheduledTriggers.single;
      expect(trigger.hour, 8);
      expect((await stack.repository.getAlarmById(id))?.nextTriggerAt,
          trigger);
    });

    test('disabling edit cancels the native schedule', () async {
      final int id = await stack.insertAlarm(hour: 7);
      await stack.coordinator.scheduleAlarm(id);

      final Alarm? current = await stack.repository.getAlarmById(id);
      final AlarmUiResult result = await stack.controller.updateAlarm(
        current!.copyWith(enabled: false),
      );

      expect(result.ok, isTrue);
      expect(stack.scheduler.cancelledIds, contains(id));
      final Alarm? stored = await stack.repository.getAlarmById(id);
      expect(stored?.enabled, isFalse);
      expect(stored?.nextTriggerAt, isNull);
    });

    test('missing row is reported', () async {
      final int id = await stack.insertAlarm();
      final Alarm? current = await stack.repository.getAlarmById(id);
      final AlarmUiResult result = await stack.controller.updateAlarm(
        current!.copyWith(id: id + 100),
      );

      expect(result.ok, isFalse);
      expect(result.persisted, isFalse);
      expect(result.messageKey, 'msgAlarmMissing');
    });
  });

  group('setEnabled', () {
    test('enabling schedules and reports', () async {
      final int id = await stack.insertAlarm(enabled: false);
      final AlarmUiResult result = await stack.controller.setEnabled(id, true);

      expect(result.ok, isTrue);
      expect(result.messageKey, 'msgAlarmEnabled');
      expect(stack.scheduler.scheduledIds, <int>[id]);
      final Alarm? stored = await stack.repository.getAlarmById(id);
      expect(stored?.enabled, isTrue);
      expect(stored?.nextTriggerAt, isNotNull);
    });

    test('enabling without permission keeps the flag, reports gap',
        () async {
      stack.scheduler.canSchedule = false;
      final int id = await stack.insertAlarm(enabled: false);
      final AlarmUiResult result = await stack.controller.setEnabled(id, true);

      expect(result.ok, isFalse);
      expect(result.persisted, isTrue);
      expect(result.messageKey, 'msgNoPermission');
      expect((await stack.repository.getAlarmById(id))?.enabled, isTrue);
    });

    test('enabling a missing alarm is reported', () async {
      final AlarmUiResult result =
          await stack.controller.setEnabled(999, true);
      expect(result.ok, isFalse);
      expect(result.persisted, isFalse);
      expect(result.messageKey, 'msgAlarmMissing');
      expect(stack.scheduler.calls, isEmpty);
    });

    test('disabling cancels and clears the trigger', () async {
      final int id = await stack.insertAlarm();
      await stack.coordinator.scheduleAlarm(id);
      stack.scheduler.cancelledIds.clear();

      final AlarmUiResult result =
          await stack.controller.setEnabled(id, false);

      expect(result.ok, isTrue);
      expect(result.messageKey, 'msgAlarmDisabled');
      expect(stack.scheduler.cancelledIds, <int>[id]);
      final Alarm? stored = await stack.repository.getAlarmById(id);
      expect(stored?.enabled, isFalse);
      expect(stored?.nextTriggerAt, isNull);
    });

    test('disabling with cancel failure keeps the flag, reports gap',
        () async {
      final int id = await stack.insertAlarm();
      stack.scheduler.cancelError = StateError('bridge down');
      final AlarmUiResult result =
          await stack.controller.setEnabled(id, false);

      expect(result.ok, isFalse);
      expect(result.persisted, isTrue);
      expect(result.messageKey, 'msgScheduleFailed');
      expect((await stack.repository.getAlarmById(id))?.enabled, isFalse);
    });

    test('disabling a missing alarm is a no-op success', () async {
      final AlarmUiResult result =
          await stack.controller.setEnabled(999, false);
      expect(result.ok, isTrue);
      expect(result.messageKey, 'msgAlarmDisabled');
    });
  });

  group('deleteAlarm', () {
    test('cancels the schedule, then deletes the row', () async {
      final int id = await stack.insertAlarm();
      await stack.coordinator.scheduleAlarm(id);

      final AlarmUiResult result = await stack.controller.deleteAlarm(id);

      expect(result.ok, isTrue);
      expect(result.messageKey, 'msgAlarmDeleted');
      expect(stack.scheduler.cancelledIds, contains(id));
      expect(await stack.repository.getAlarmById(id), isNull);
    });

    test('cancel failure keeps the row and reports', () async {
      final int id = await stack.insertAlarm();
      stack.scheduler.cancelError = StateError('bridge down');

      final AlarmUiResult result = await stack.controller.deleteAlarm(id);

      expect(result.ok, isFalse);
      expect(result.persisted, isFalse);
      expect(result.messageKey, 'msgDeleteFailed');
      expect(await stack.repository.getAlarmById(id), isNotNull);
    });

    test('missing alarm is reported', () async {
      final AlarmUiResult result = await stack.controller.deleteAlarm(999);
      expect(result.ok, isFalse);
      expect(result.messageKey, 'msgAlarmMissing');
    });
  });
}
