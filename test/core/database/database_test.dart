import 'package:alarmx/core/database/database.dart';
import 'package:alarmx/core/models/models.dart';
import 'package:alarmx/core/repositories/alarm_history_repository.dart';
import 'package:alarmx/core/repositories/alarm_repository.dart';
import 'package:alarmx/core/repositories/app_settings_repository.dart';
import 'package:alarmx/core/repositories/mission_repository.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

// Repository + database integration tests. Every test runs against a fresh
// in-memory database, so no device, emulator, or files are required.

void main() {
  late AppDatabase db;
  late AlarmRepository alarms;
  late MissionRepository missions;
  late AlarmHistoryRepository history;
  late AppSettingsRepository settings;

  setUp(() {
    db = AppDatabase.connect(NativeDatabase.memory());
    alarms = DriftAlarmRepository(db.alarmDao);
    missions = DriftMissionRepository(db.missionDao);
    history = DriftAlarmHistoryRepository(db.alarmHistoryDao);
    settings = DriftAppSettingsRepository(db.appSettingsDao);
  });

  tearDown(() async {
    await db.close();
  });

  group('database', () {
    test('initializes at schema version 1 with empty tables', () async {
      expect(db.schemaVersion, 1);
      expect(await alarms.getAlarms(), isEmpty);
      expect(await history.getAllHistory(), isEmpty);
    });
  });

  group('alarms', () {
    test('insert and read round-trip with schema defaults', () async {
      final int id = await alarms.createAlarm(
        const AlarmsCompanion(hour: Value(7), minute: Value(30)),
      );
      final Alarm? alarm = await alarms.getAlarmById(id);
      expect(alarm, isNotNull);
      expect(alarm!.hour, 7);
      expect(alarm.minute, 30);
      expect(alarm.enabled, isTrue);
      expect(alarm.repeatType, RepeatType.once.dbValue);
      expect(alarm.volume, 80);
    });

    test('insert stores typed repeat columns', () async {
      final RepeatDays days = RepeatDays.fromDays(
        <Weekday>{Weekday.monday, Weekday.friday},
      );
      final int id = await alarms.createAlarm(
        AlarmsCompanion(
          hour: const Value(8),
          minute: const Value(0),
          label: const Value('Workdays'),
          repeatType: Value(RepeatType.custom.dbValue),
          repeatDays: Value(days.mask),
        ),
      );
      final Alarm? alarm = await alarms.getAlarmById(id);
      expect(alarm!.repeatType, 'custom');
      expect(RepeatDays(alarm.repeatDays!).has(Weekday.monday), isTrue);
      expect(RepeatDays(alarm.repeatDays!).has(Weekday.tuesday), isFalse);
    });

    test('update replaces the stored row', () async {
      final int id = await alarms.createAlarm(
        const AlarmsCompanion(hour: Value(7), minute: Value(30)),
      );
      final Alarm? created = await alarms.getAlarmById(id);
      final bool updated = await alarms.updateAlarm(
        created!.copyWith(hour: 9, label: const Value('Evening')),
      );
      expect(updated, isTrue);
      final Alarm? reread = await alarms.getAlarmById(id);
      expect(reread!.hour, 9);
      expect(reread.label, 'Evening');
    });

    test('enable and disable flip stored state', () async {
      final int id = await alarms.createAlarm(
        const AlarmsCompanion(hour: Value(7), minute: Value(30)),
      );
      expect(await alarms.setAlarmEnabled(id, false), isTrue);
      expect((await alarms.getAlarmById(id))!.enabled, isFalse);
      expect(await alarms.setAlarmEnabled(id, true), isTrue);
      expect((await alarms.getAlarmById(id))!.enabled, isTrue);
    });

    test('enabled query returns only enabled alarms', () async {
      await alarms.createAlarm(
        const AlarmsCompanion(hour: Value(7), minute: Value(30)),
      );
      await alarms.createAlarm(
        const AlarmsCompanion(
          hour: Value(8),
          minute: Value(0),
          enabled: Value(false),
        ),
      );
      final List<Alarm> enabled = await alarms.getEnabledAlarms();
      expect(enabled.length, 1);
      expect(enabled.single.hour, 7);
    });

    test('watch emits the current alarms', () async {
      final int id = await alarms.createAlarm(
        const AlarmsCompanion(hour: Value(7), minute: Value(30)),
      );
      final List<Alarm> first = await alarms.watchAlarms().first;
      expect(first.map((Alarm alarm) => alarm.id), contains(id));
    });

    test('delete removes the alarm', () async {
      final int id = await alarms.createAlarm(
        const AlarmsCompanion(hour: Value(7), minute: Value(30)),
      );
      expect(await alarms.deleteAlarm(id), isTrue);
      expect(await alarms.getAlarmById(id), isNull);
    });

    test('deleting an alarm cascades to its missions', () async {
      final int id = await alarms.createAlarm(
        const AlarmsCompanion(hour: Value(7), minute: Value(30)),
      );
      await missions.createMission(
        MissionsCompanion(
          alarmId: Value(id),
          type: Value(MissionType.math.dbValue),
        ),
      );
      expect(await alarms.deleteAlarm(id), isTrue);
      expect(await missions.getMissionsForAlarm(id), isEmpty);
    });

    test('missing ids behave safely', () async {
      expect(await alarms.getAlarmById(999), isNull);
      expect(await alarms.deleteAlarm(999), isFalse);
      expect(await alarms.setAlarmEnabled(999, false), isFalse);
      final int id = await alarms.createAlarm(
        const AlarmsCompanion(hour: Value(7), minute: Value(30)),
      );
      final Alarm? created = await alarms.getAlarmById(id);
      expect(await alarms.deleteAlarm(id), isTrue);
      expect(await alarms.updateAlarm(created!), isFalse);
    });
  });

  group('missions', () {
    test('missions are ordered by execution order', () async {
      final int alarmId = await alarms.createAlarm(
        const AlarmsCompanion(hour: Value(7), minute: Value(30)),
      );
      await missions.createMission(
        MissionsCompanion(
          alarmId: Value(alarmId),
          type: Value(MissionType.qr.dbValue),
          orderIndex: const Value(1),
        ),
      );
      final int firstId = await missions.createMission(
        MissionsCompanion(
          alarmId: Value(alarmId),
          type: Value(MissionType.math.dbValue),
          orderIndex: const Value(0),
          configJson: const Value('{"count":3}'),
        ),
      );
      final List<Mission> ordered =
          await missions.getMissionsForAlarm(alarmId);
      expect(ordered.length, 2);
      expect(ordered.first.id, firstId);
      expect(ordered.first.type, MissionType.math.dbValue);

      final Mission? byId = await missions.getMissionById(firstId);
      expect(byId!.configJson, '{"count":3}');
    });

    test('delete removes a single mission', () async {
      final int alarmId = await alarms.createAlarm(
        const AlarmsCompanion(hour: Value(7), minute: Value(30)),
      );
      final int id = await missions.createMission(
        MissionsCompanion(
          alarmId: Value(alarmId),
          type: Value(MissionType.shake.dbValue),
        ),
      );
      expect(await missions.deleteMission(id), isTrue);
      expect(await missions.getMissionById(id), isNull);
    });

    test('missing ids behave safely', () async {
      expect(await missions.getMissionById(999), isNull);
      expect(await missions.deleteMission(999), isFalse);
    });
  });

  group('history', () {
    test('insert, update and ordered queries', () async {
      final int alarmId = await alarms.createAlarm(
        const AlarmsCompanion(hour: Value(7), minute: Value(30)),
      );
      final DateTime first = DateTime(2026, 10, 6, 7, 30);
      final DateTime second = DateTime(2026, 10, 6, 8, 30);
      final int firstId = await history.insertHistory(
        AlarmHistoryCompanion(startedAt: Value(first), alarmId: Value(alarmId)),
      );
      await history.insertHistory(
        AlarmHistoryCompanion(
          startedAt: Value(second),
          alarmId: Value(alarmId),
        ),
      );
      final AlarmHistoryData? entry = await history.getHistoryById(firstId);
      expect(entry!.result, AlarmResult.ongoing.dbValue);
      expect(
        await history.updateHistory(
          entry.copyWith(
            stoppedAt: Value(second),
            result: AlarmResult.success.dbValue,
          ),
        ),
        isTrue,
      );
      final List<AlarmHistoryData> ordered =
          await history.getHistoryForAlarm(alarmId);
      expect(ordered.length, 2);
      expect(ordered.first.startedAt, second);
      expect((await history.getHistoryById(firstId))!.result, 'success');
    });

    test('missing ids return null', () async {
      expect(await history.getHistoryById(999), isNull);
    });
  });

  group('settings', () {
    test('first read creates defaults, update persists', () async {
      final AppSetting created = await settings.getSettings();
      expect(created.id, 1);
      expect(created.language, 'ar');
      expect(created.theme, 'system');
      expect(created.defaultVolume, 80);

      await settings.updateSettings(
        const AppSettingsCompanion(language: Value('en')),
      );
      final AppSetting updated = await settings.getSettings();
      expect(updated.language, 'en');
      expect(updated.theme, 'system');
    });
  });
}
