// Tests for MissionService over a real in-memory Drift stack:
// load filtering, validation, order normalization, atomic replace.

import 'package:alarmx/core/database/database.dart';
import 'package:alarmx/core/models/models.dart';
import 'package:alarmx/core/repositories/mission_repository.dart';
import 'package:alarmx/features/missions/mission_config.dart';
import 'package:alarmx/features/missions/mission_service.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

/// Repository wrapper that fails the next atomic replace, to prove the
/// stored list is untouched when a save fails midway.
class _FailingReplaceRepository implements MissionRepository {
  _FailingReplaceRepository(this._inner);

  final MissionRepository _inner;

  @override
  Future<List<Mission>> getMissionsForAlarm(int alarmId) =>
      _inner.getMissionsForAlarm(alarmId);

  @override
  Future<Mission?> getMissionById(int id) => _inner.getMissionById(id);

  @override
  Future<int> createMission(MissionsCompanion entry) =>
      _inner.createMission(entry);

  @override
  Future<bool> updateMission(Mission entry) => _inner.updateMission(entry);

  @override
  Future<bool> deleteMission(int id) => _inner.deleteMission(id);

  @override
  Future<int> deleteMissionsForAlarm(int alarmId) =>
      _inner.deleteMissionsForAlarm(alarmId);

  @override
  Future<void> replaceMissionsForAlarm(
    int alarmId,
    List<MissionsCompanion> entries,
  ) {
    throw StateError('boom');
  }
}

void main() {
  late AppDatabase db;
  late MissionService service;

  MissionDraft typingDraft(String text, {bool required = true}) {
    return MissionDraft(
      type: MissionType.typing,
      config: TypingMissionConfig(text),
      required: required,
    );
  }

  setUp(() {
    db = AppDatabase.connect(NativeDatabase.memory());
    service = MissionService(DriftMissionRepository(db.missionDao));
  });

  tearDown(() async {
    await db.close();
  });

  Future<int> insertAlarm() {
    return db.into(db.alarms).insert(
          AlarmsCompanion.insert(hour: 7, minute: 30),
        );
  }

  group('getMissionsForAlarm', () {
    test('empty alarm yields no entries and no invalid rows', () async {
      final int alarmId = await insertAlarm();
      final AlarmMissions loaded = await service.getMissionsForAlarm(alarmId);
      expect(loaded.entries, isEmpty);
      expect(loaded.invalidCount, 0);
    });

    test('loads entries in orderIndex order', () async {
      final int alarmId = await insertAlarm();
      await service.saveMissionsForAlarm(alarmId, <MissionDraft>[
        typingDraft('first'),
        MissionDraft(
          type: MissionType.shake,
          config: const ShakeMissionConfig(5),
          required: false,
        ),
        MissionDraft(
          type: MissionType.math,
          config: const MathMissionConfig(
            questionCount: 3,
            difficulty: MathDifficulty.easy,
          ),
        ),
      ]);
      final AlarmMissions loaded = await service.getMissionsForAlarm(alarmId);
      expect(loaded.invalidCount, 0);
      expect(loaded.entries.map((MissionEntry e) => e.type).toList(),
          <MissionType>[MissionType.typing, MissionType.shake, MissionType.math]);
      expect(loaded.entries.map((MissionEntry e) => e.orderIndex).toList(),
          <int>[0, 1, 2]);
      expect(loaded.entries[1].required, isFalse);
    });

    test('none rows are dropped silently, bad rows are counted', () async {
      final int alarmId = await insertAlarm();
      final MissionDao dao = db.missionDao;
      await dao.insertMission(
        MissionsCompanion.insert(alarmId: alarmId, type: 'none'),
      );
      await dao.insertMission(
        MissionsCompanion.insert(
          alarmId: alarmId,
          type: MissionType.typing.dbValue,
          configJson: const Value('junk'),
          orderIndex: const Value(1),
        ),
      );
      await dao.insertMission(
        MissionsCompanion.insert(
          alarmId: alarmId,
          type: MissionType.typing.dbValue,
          configJson: const Value('{"text": ""}'),
          orderIndex: const Value(2),
        ),
      );
      await dao.insertMission(
        MissionsCompanion.insert(
          alarmId: alarmId,
          type: MissionType.typing.dbValue,
          configJson: const Value('{"text": "ok"}'),
          orderIndex: const Value(3),
        ),
      );
      final AlarmMissions loaded = await service.getMissionsForAlarm(alarmId);
      expect(loaded.entries, hasLength(1));
      expect(
        (loaded.entries.single.config as TypingMissionConfig).expectedText,
        'ok',
      );
      expect(loaded.invalidCount, 2);
    });
  });

  group('validateDrafts', () {
    test('empty list is valid, invalid drafts report keys', () {
      expect(MissionService.validateDrafts(<MissionDraft>[]), isEmpty);
      expect(
        MissionService.validateDrafts(<MissionDraft>[
          typingDraft('ok'),
          typingDraft(''),
          MissionDraft.withDefaults(MissionType.none),
        ]),
        <String>['missionFieldRequired', 'msgMissionInvalid'],
      );
    });
  });

  group('saveMissionsForAlarm', () {
    test('invalid drafts throw without writing anything', () async {
      final int alarmId = await insertAlarm();
      await service.saveMissionsForAlarm(alarmId, <MissionDraft>[
        typingDraft('kept'),
      ]);
      await expectLater(
        service.saveMissionsForAlarm(alarmId, <MissionDraft>[
          typingDraft(''),
        ]),
        throwsA(isA<MissionValidationException>()),
      );
      final AlarmMissions loaded = await service.getMissionsForAlarm(alarmId);
      expect(loaded.entries, hasLength(1));
      expect(
        (loaded.entries.single.config as TypingMissionConfig).expectedText,
        'kept',
      );
    });

    test('replace drops removed rows and normalizes order', () async {
      final int alarmId = await insertAlarm();
      await service.saveMissionsForAlarm(alarmId, <MissionDraft>[
        typingDraft('a'),
        typingDraft('b'),
        typingDraft('c'),
      ]);
      await service.saveMissionsForAlarm(alarmId, <MissionDraft>[
        typingDraft('z', required: false),
      ]);
      final AlarmMissions loaded = await service.getMissionsForAlarm(alarmId);
      expect(loaded.entries, hasLength(1));
      expect(
        (loaded.entries.single.config as TypingMissionConfig).expectedText,
        'z',
      );
      expect(loaded.entries.single.orderIndex, 0);
      expect(loaded.entries.single.required, isFalse);
    });

    test('empty list clears the missions', () async {
      final int alarmId = await insertAlarm();
      await service.saveMissionsForAlarm(alarmId, <MissionDraft>[
        typingDraft('a'),
      ]);
      await service.saveMissionsForAlarm(alarmId, <MissionDraft>[]);
      final AlarmMissions loaded = await service.getMissionsForAlarm(alarmId);
      expect(loaded.entries, isEmpty);
      expect(loaded.invalidCount, 0);
    });

    test('failed replace leaves the stored list untouched', () async {
      final int alarmId = await insertAlarm();
      await service.saveMissionsForAlarm(alarmId, <MissionDraft>[
        typingDraft('before'),
      ]);
      final MissionService failing = MissionService(
        _FailingReplaceRepository(DriftMissionRepository(db.missionDao)),
      );
      await expectLater(
        failing.saveMissionsForAlarm(alarmId, <MissionDraft>[
          typingDraft('after'),
        ]),
        throwsStateError,
      );
      final AlarmMissions loaded = await service.getMissionsForAlarm(alarmId);
      expect(loaded.entries, hasLength(1));
      expect(
        (loaded.entries.single.config as TypingMissionConfig).expectedText,
        'before',
      );
    });
  });
}
