import 'package:alarmx/core/database/database.dart';
import 'package:alarmx/core/models/models.dart';
import 'package:alarmx/core/repositories/mission_repository.dart';
import 'package:alarmx/features/missions/mission_config.dart';
import 'package:alarmx/features/missions/mission_service.dart';
import 'package:alarmx/features/ringing_alarm/ringing_alarm_bridge.dart';
import 'package:alarmx/features/ringing_alarm/ringing_launch.dart';
import 'package:alarmx/features/ringing_alarm/ringing_session.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';

import '../../support/test_doubles.dart';

// RingingSession tests: load/linkage, strict-gated stop, snooze, and
// emergency exit over a real in-memory stack with a fake bridge.

class _FakeBridge implements RingingAlarmBridge {
  int stops = 0;
  int failuresLeft = 0;

  @override
  Future<RingingLaunch?> consumeRingingLaunch() async => null;

  @override
  Future<void> stopRingingAlarm(int alarmId) async {
    if (failuresLeft > 0) {
      failuresLeft -= 1;
      throw StateError('stop failed');
    }
    stops += 1;
  }
}

class _NeverRepo implements MissionRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) {
    throw UnimplementedError('never called');
  }
}

class _FailingMissionService extends MissionService {
  _FailingMissionService() : super(_NeverRepo());

  @override
  Future<AlarmMissions> getMissionsForAlarm(int alarmId) async {
    throw StateError('load failed');
  }
}

void main() {
  late TestStack stack;

  setUp(() {
    stack = TestStack();
  });

  tearDown(() async {
    await stack.close();
  });

  final DateTime ringTime = DateTime(2026, 10, 8, 7, 0);

  Future<int> ringingAlarm({
    bool strictMode = false,
    bool snoozeEnabled = true,
    int snoozeMinutes = 5,
    int snoozeMaxCount = 3,
  }) async {
    final int id = await stack.insertAlarm(hour: 7, minute: 0);
    final Alarm? alarm = await stack.repository.getAlarmById(id);
    await stack.repository.updateAlarm(
      alarm!.copyWith(
        strictMode: strictMode,
        snoozeEnabled: snoozeEnabled,
        snoozeMinutes: snoozeMinutes,
        snoozeMaxCount: snoozeMaxCount,
        nextTriggerAt: Value<DateTime?>(ringTime),
      ),
    );
    return id;
  }

  Future<void> seedTyping(int alarmId) {
    return stack.missions.saveMissionsForAlarm(alarmId, <MissionDraft>[
      MissionDraft(
        type: MissionType.typing,
        config: const TypingMissionConfig('wake'),
      ),
    ]);
  }

  RingingSession newSession(
    int alarmId, {
    int? tokenMillis,
    _FakeBridge? bridge,
    MissionService? missions,
    DateTime Function()? clock,
  }) {
    return RingingSession(
      launch: RingingLaunch(
        alarmId: alarmId,
        triggerAtMillis: tokenMillis ?? ringTime.millisecondsSinceEpoch,
      ),
      alarms: stack.repository,
      missions: missions ?? stack.missions,
      history: stack.history,
      coordinator: stack.coordinator,
      bridge: bridge ?? _FakeBridge(),
      clock: clock ?? (() => ringTime),
    );
  }

  Future<List<AlarmHistoryData>> rowsFor(int alarmId) {
    return stack.history.getHistoryForAlarm(alarmId);
  }

  /// Flushes the event queue until [done] or the bound; fails loudly on
  /// timeout instead of hanging (no arbitrary delays).
  Future<void> pumpUntil(bool Function() done) async {
    for (int i = 0; i < 200 && !done(); i++) {
      await Future<void>.delayed(Duration.zero);
    }
    expect(done(), isTrue, reason: 'session did not settle');
  }

  group('load', () {
    test('fresh ring opens a new episode', () async {
      final int id = await ringingAlarm();
      await seedTyping(id);
      final RingingSession session = newSession(id);
      addTearDown(session.dispose);

      await session.load();

      expect(session.isLoading, isFalse);
      expect(session.loadFailed, isFalse);
      expect(session.alarm?.id, id);
      expect(session.missionSession?.totalCount, 1);
      expect(session.episodeId, isNotNull);
      expect(session.usedSnoozes, 0);
      expect(session.canSnooze, isTrue);
      expect(session.snoozesRemaining, 3);
      final List<AlarmHistoryData> rows = await rowsFor(id);
      expect(rows, hasLength(1));
      expect(rows.single.result, AlarmResult.ongoing.dbValue);
    });

    test('snoozed continuation reuses its episode', () async {
      final int id = await ringingAlarm();
      await seedTyping(id);
      final DateTime target = ringTime.add(const Duration(minutes: 5));
      await stack.history.insertHistory(
        AlarmHistoryCompanion.insert(
          alarmId: Value<int?>(id),
          startedAt: ringTime.subtract(const Duration(minutes: 5)),
          stoppedAt: Value<DateTime?>(target),
          result: Value<String>(AlarmResult.ongoing.dbValue),
          snoozeCount: const Value<int>(1),
        ),
      );
      final RingingSession session = newSession(
        id,
        tokenMillis: target.millisecondsSinceEpoch,
        clock: () => target,
      );
      addTearDown(session.dispose);

      await session.load();

      expect(session.usedSnoozes, 1);
      expect(session.snoozesRemaining, 2);
      expect(await rowsFor(id), hasLength(1));
    });

    test('stale open episode is closed and replaced', () async {
      final int id = await ringingAlarm();
      final int staleId = await stack.history.insertHistory(
        AlarmHistoryCompanion.insert(
          alarmId: Value<int?>(id),
          startedAt: ringTime.subtract(const Duration(days: 1)),
          stoppedAt:
              Value<DateTime?>(ringTime.subtract(const Duration(days: 1))),
          result: Value<String>(AlarmResult.ongoing.dbValue),
          snoozeCount: const Value<int>(2),
        ),
      );
      final RingingSession session = newSession(id);
      addTearDown(session.dispose);

      await session.load();

      expect(session.usedSnoozes, 0);
      expect(session.episodeId, isNot(staleId));
      expect(
        (await stack.history.getHistoryById(staleId))?.result,
        AlarmResult.failed.dbValue,
      );
      expect(await rowsFor(id), hasLength(2));
    });

    test('missing alarm degrades without history', () async {
      final RingingSession session = newSession(999);
      addTearDown(session.dispose);

      await session.load();

      expect(session.isLoading, isFalse);
      expect(session.alarm, isNull);
      expect(session.episodeId, isNull);
      expect(session.canSnooze, isFalse);
      expect(session.canStop, isTrue);
      expect(await rowsFor(999), isEmpty);
    });

    test('mission load failure stays stoppable', () async {
      final int id = await ringingAlarm(strictMode: true);
      final RingingSession session = newSession(
        id,
        missions: _FailingMissionService(),
      );
      addTearDown(session.dispose);

      await session.load();

      expect(session.loadFailed, isTrue);
      expect(session.missionSession, isNull);
      expect(session.canStop, isTrue);
    });
  });

  group('stop', () {
    test('non-strict incomplete ring stops', () async {
      final int id = await ringingAlarm();
      await seedTyping(id);
      final _FakeBridge bridge = _FakeBridge();
      final RingingSession session = newSession(id, bridge: bridge);
      addTearDown(session.dispose);
      await session.load();

      expect(await session.stop(), isTrue);

      expect(session.outcome, RingingOutcome.stopped);
      expect(bridge.stops, 1);
      final List<AlarmHistoryData> rows = await rowsFor(id);
      expect(rows.single.result, AlarmResult.success.dbValue);
      expect(rows.single.stoppedAt, isNotNull);
    });

    test('strict incomplete ring refuses to stop', () async {
      final int id = await ringingAlarm(strictMode: true);
      await seedTyping(id);
      final _FakeBridge bridge = _FakeBridge();
      final RingingSession session = newSession(id, bridge: bridge);
      addTearDown(session.dispose);
      await session.load();

      expect(session.canStop, isFalse);
      expect(await session.stop(), isFalse);

      expect(session.outcome, RingingOutcome.none);
      expect(bridge.stops, 0);
      expect(
        (await rowsFor(id)).single.result,
        AlarmResult.ongoing.dbValue,
      );
    });

    test('strict complete ring stops', () async {
      final int id = await ringingAlarm(strictMode: true);
      await seedTyping(id);
      final _FakeBridge bridge = _FakeBridge();
      final RingingSession session = newSession(id, bridge: bridge);
      addTearDown(session.dispose);
      await session.load();
      final int missionId = (await stack.missions.getMissionsForAlarm(id))
          .entries
          .single
          .id;
      session.missionSession!.completeMission(missionId);
      await pumpUntil(() => session.outcome != RingingOutcome.none);

      // Mission success auto-stopped the ring through the gated path.
      expect(session.outcome, RingingOutcome.stopped);
      expect(bridge.stops, 1);
      expect(
        (await rowsFor(id)).single.result,
        AlarmResult.success.dbValue,
      );
    });

    test('strict ring without missions stops', () async {
      final int id = await ringingAlarm(strictMode: true);
      final _FakeBridge bridge = _FakeBridge();
      final RingingSession session = newSession(id, bridge: bridge);
      addTearDown(session.dispose);
      await session.load();

      expect(session.canStop, isTrue);
      expect(await session.stop(), isTrue);
      expect(bridge.stops, 1);
    });

    test('second stop is a no-op', () async {
      final int id = await ringingAlarm();
      final _FakeBridge bridge = _FakeBridge();
      final RingingSession session = newSession(id, bridge: bridge);
      addTearDown(session.dispose);
      await session.load();

      expect(await session.stop(), isTrue);
      expect(await session.stop(), isFalse);
      expect(bridge.stops, 1);
    });

    test('failed stop surfaces a retry and recovers', () async {
      final int id = await ringingAlarm();
      final _FakeBridge bridge = _FakeBridge()..failuresLeft = 1;
      final RingingSession session = newSession(id, bridge: bridge);
      addTearDown(session.dispose);
      await session.load();

      expect(await session.stop(), isFalse);
      expect(session.outcome, RingingOutcome.none);
      expect(session.errorKey, 'ringingStopFailed');

      expect(await session.stop(), isTrue);
      expect(session.outcome, RingingOutcome.stopped);
      expect(bridge.stops, 1);
    });
  });

  group('snooze', () {
    test('snooze schedules, records, and stops', () async {
      final int id = await ringingAlarm();
      await seedTyping(id);
      final _FakeBridge bridge = _FakeBridge();
      final RingingSession session = newSession(id, bridge: bridge);
      addTearDown(session.dispose);
      await session.load();

      expect(await session.snooze(), isTrue);

      final DateTime target = ringTime.add(const Duration(minutes: 5));
      expect(session.outcome, RingingOutcome.snoozed);
      expect(bridge.stops, 1);
      expect(stack.scheduler.scheduledTriggers.single, target);
      expect(
        (await stack.repository.getAlarmById(id))?.nextTriggerAt,
        target,
      );
      final List<AlarmHistoryData> rows = await rowsFor(id);
      expect(rows.single.result, AlarmResult.ongoing.dbValue);
      expect(rows.single.snoozeCount, 1);
      expect(rows.single.stoppedAt, target);
    });

    test('snooze during strict missions is allowed', () async {
      final int id = await ringingAlarm(strictMode: true);
      await seedTyping(id);
      final _FakeBridge bridge = _FakeBridge();
      final RingingSession session = newSession(id, bridge: bridge);
      addTearDown(session.dispose);
      await session.load();
      expect(session.canStop, isFalse);

      // Snooze defers (missions re-arm); it never skips them.
      expect(await session.snooze(), isTrue);
      expect(session.outcome, RingingOutcome.snoozed);
    });

    test('exhausted snooze is refused without stopping', () async {
      final int id =
          await ringingAlarm(snoozeMaxCount: 1);
      final _FakeBridge bridge = _FakeBridge();
      final RingingSession session = newSession(id, bridge: bridge);
      addTearDown(session.dispose);
      await session.load();

      expect(await session.snooze(), isTrue);
      // A second ring continues the episode with the count spent.
      final DateTime target = ringTime.add(const Duration(minutes: 5));
      final RingingSession again = newSession(
        id,
        tokenMillis: target.millisecondsSinceEpoch,
        bridge: bridge,
        clock: () => target,
      );
      addTearDown(again.dispose);
      await again.load();

      expect(again.usedSnoozes, 1);
      expect(again.canSnooze, isFalse);
      expect(await again.snooze(), isFalse);
      expect(again.outcome, RingingOutcome.none);
      expect(bridge.stops, 1);
      expect(stack.scheduler.scheduledTriggers, hasLength(1));
    });

    test('disabled snooze is refused', () async {
      final int id = await ringingAlarm(snoozeEnabled: false);
      final RingingSession session = newSession(id);
      addTearDown(session.dispose);
      await session.load();

      expect(session.canSnooze, isFalse);
      expect(await session.snooze(), isFalse);
      expect(session.outcome, RingingOutcome.none);
    });

    test('legacy ring without a token cannot snooze', () async {
      final int id = await ringingAlarm();
      final RingingSession session = RingingSession(
        launch: RingingLaunch(alarmId: id),
        alarms: stack.repository,
        missions: stack.missions,
        history: stack.history,
        coordinator: stack.coordinator,
        bridge: _FakeBridge(),
        clock: () => ringTime,
      );
      addTearDown(session.dispose);
      await session.load();

      expect(session.canSnooze, isFalse);
      expect(await session.snooze(), isFalse);
    });

    test('failed schedule surfaces msgSnoozeFailed and keeps ringing',
        () async {
      final int id = await ringingAlarm();
      final _FakeBridge bridge = _FakeBridge();
      final RingingSession session = newSession(id, bridge: bridge);
      addTearDown(session.dispose);
      await session.load();
      stack.scheduler.canSchedule = false;

      expect(await session.snooze(), isFalse);
      expect(session.outcome, RingingOutcome.none);
      expect(session.errorKey, 'msgSnoozeFailed');
      expect(bridge.stops, 0);
    });

    test('failed stop after a committed snooze retries the stop leg only',
        () async {
      final int id = await ringingAlarm();
      final _FakeBridge bridge = _FakeBridge()..failuresLeft = 1;
      final RingingSession session = newSession(id, bridge: bridge);
      addTearDown(session.dispose);
      await session.load();

      expect(await session.snooze(), isFalse);
      expect(session.outcome, RingingOutcome.none);
      expect(session.errorKey, 'ringingStopFailed');

      // The retry must not schedule (or record) a second snooze.
      expect(await session.snooze(), isTrue);
      expect(session.outcome, RingingOutcome.snoozed);
      expect(bridge.stops, 1);
      expect(stack.scheduler.scheduledTriggers, hasLength(1));
      expect((await rowsFor(id)).single.snoozeCount, 1);
    });

    test('second snooze on a finished session is a no-op', () async {
      final int id = await ringingAlarm();
      final _FakeBridge bridge = _FakeBridge();
      final RingingSession session = newSession(id, bridge: bridge);
      addTearDown(session.dispose);
      await session.load();

      expect(await session.snooze(), isTrue);
      expect(await session.snooze(), isFalse);
      expect(stack.scheduler.scheduledTriggers, hasLength(1));
    });
  });

  group('emergencyExit', () {
    test('emergency records and stops without missions', () async {
      final int id = await ringingAlarm(strictMode: true);
      await seedTyping(id);
      final _FakeBridge bridge = _FakeBridge();
      final RingingSession session = newSession(id, bridge: bridge);
      addTearDown(session.dispose);
      await session.load();

      expect(await session.emergencyExit(), isTrue);

      expect(session.outcome, RingingOutcome.emergency);
      expect(bridge.stops, 1);
      final List<AlarmHistoryData> rows = await rowsFor(id);
      expect(rows.single.result, AlarmResult.emergencyStop.dbValue);
      // Configuration is untouched by the emergency path.
      final Alarm? alarm = await stack.repository.getAlarmById(id);
      expect(alarm?.strictMode, isTrue);
      expect(alarm?.enabled, isTrue);
      expect(alarm?.hour, 7);
    });

    test('emergency works without an alarm row', () async {
      final _FakeBridge bridge = _FakeBridge();
      final RingingSession session = newSession(999, bridge: bridge);
      addTearDown(session.dispose);
      await session.load();

      expect(await session.emergencyExit(), isTrue);
      expect(bridge.stops, 1);
    });

    test('failed emergency stop retries cleanly', () async {
      final int id = await ringingAlarm();
      final _FakeBridge bridge = _FakeBridge()..failuresLeft = 2;
      final RingingSession session = newSession(id, bridge: bridge);
      addTearDown(session.dispose);
      await session.load();

      expect(await session.emergencyExit(), isFalse);
      expect(await session.emergencyExit(), isFalse);
      expect(session.errorKey, 'ringingStopFailed');
      expect(await session.emergencyExit(), isTrue);
      expect(session.outcome, RingingOutcome.emergency);
      expect(bridge.stops, 1);
    });
  });
}
