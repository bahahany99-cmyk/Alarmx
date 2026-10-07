// Tests for MissionSession: ordering, required/optional, idempotent
// completion, progress, and listener behavior.

import 'package:alarmx/core/models/models.dart';
import 'package:alarmx/features/missions/mission_config.dart';
import 'package:alarmx/features/missions/mission_engine.dart';
import 'package:flutter_test/flutter_test.dart';

MissionEntry entryOf(int id, {bool required = true, int? orderIndex}) {
  return MissionEntry(
    id: id,
    alarmId: 9,
    type: MissionType.typing,
    orderIndex: orderIndex ?? id,
    config: const TypingMissionConfig('x'),
    required: required,
  );
}

void main() {
  group('empty session', () {
    test('is trivially complete with no current mission', () {
      final MissionSession session = MissionSession(<MissionEntry>[]);
      expect(session.isComplete, isTrue);
      expect(session.current, isNull);
      expect(session.currentIndex, 0);
      expect(session.totalCount, 0);
      expect(session.completeMission(1), isFalse);
      expect(session.skipMission(1), isFalse);
    });
  });

  group('single mission', () {
    test('completes exactly once', () {
      final MissionSession session = MissionSession(<MissionEntry>[
        entryOf(1),
      ]);
      expect(session.isComplete, isFalse);
      expect(session.current!.id, 1);
      expect(session.currentIndex, 0);
      expect(session.completeMission(999), isFalse);
      expect(session.completeMission(1), isTrue);
      expect(session.isComplete, isTrue);
      expect(session.current, isNull);
      expect(session.currentIndex, 1);
      expect(session.completedCount, 1);
      expect(session.isCompleted(1), isTrue);
      // Duplicate completion after done is a no-op.
      expect(session.completeMission(1), isFalse);
    });

    test('required mission cannot be skipped, optional can', () {
      final MissionSession requiredSession = MissionSession(<MissionEntry>[
        entryOf(1),
      ]);
      expect(requiredSession.skipMission(1), isFalse);
      expect(requiredSession.isComplete, isFalse);

      final MissionSession optionalSession = MissionSession(<MissionEntry>[
        entryOf(2, required: false),
      ]);
      expect(optionalSession.skipMission(2), isTrue);
      expect(optionalSession.isSkipped(2), isTrue);
      expect(optionalSession.isComplete, isTrue);
      // Skipped missions cannot be completed afterwards.
      expect(optionalSession.completeMission(2), isFalse);
    });
  });

  group('multiple missions', () {
    test('execute strictly in orderIndex order, not list order', () {
      final MissionSession session = MissionSession(<MissionEntry>[
        entryOf(30, orderIndex: 2),
        entryOf(10, orderIndex: 0),
        entryOf(20, orderIndex: 1),
      ]);
      expect(
        session.entries.map((MissionEntry e) => e.id).toList(),
        <int>[10, 20, 30],
      );
      expect(session.current!.id, 10);
      // Out-of-order completion is rejected ...
      expect(session.completeMission(20), isFalse);
      expect(session.completeMission(30), isFalse);
      expect(session.current!.id, 10);
      // ... in-order completion advances.
      expect(session.completeMission(10), isTrue);
      expect(session.current!.id, 20);
      expect(session.currentIndex, 1);
      expect(session.completeMission(20), isTrue);
      expect(session.completeMission(30), isTrue);
      expect(session.isComplete, isTrue);
    });

    test('ties break by id for determinism', () {
      final MissionSession session = MissionSession(<MissionEntry>[
        entryOf(5, orderIndex: 0),
        entryOf(3, orderIndex: 0),
      ]);
      expect(session.current!.id, 3);
    });

    test('required/optional mix: optionals skipped, requireds solved', () {
      final MissionSession session = MissionSession(<MissionEntry>[
        entryOf(1),
        entryOf(2, required: false),
        entryOf(3),
      ]);
      expect(session.completeMission(1), isTrue);
      expect(session.isComplete, isFalse);
      expect(session.skipMission(2), isTrue);
      expect(session.skippedCount, 1);
      expect(session.isComplete, isFalse);
      expect(session.skipMission(3), isFalse);
      expect(session.completeMission(3), isTrue);
      expect(session.isComplete, isTrue);
      expect(session.completedCount, 2);
    });

    test('optional mission may also be completed', () {
      final MissionSession session = MissionSession(<MissionEntry>[
        entryOf(1, required: false),
      ]);
      expect(session.completeMission(1), isTrue);
      expect(session.isComplete, isTrue);
      expect(session.skippedCount, 0);
    });

    test('unresolved optional blocks completion until skipped', () {
      final MissionSession session = MissionSession(<MissionEntry>[
        entryOf(1),
        entryOf(2, required: false),
      ]);
      expect(session.completeMission(1), isTrue);
      expect(session.isComplete, isFalse);
      expect(session.current!.id, 2);
      expect(session.skipMission(2), isTrue);
      expect(session.isComplete, isTrue);
    });
  });

  group('listeners', () {
    test('notify exactly on state changes', () {
      final MissionSession session = MissionSession(<MissionEntry>[
        entryOf(1),
        entryOf(2, required: false),
      ]);
      int notifications = 0;
      session.addListener(() {
        notifications++;
      });
      expect(session.completeMission(999), isFalse);
      expect(notifications, 0);
      expect(session.completeMission(1), isTrue);
      expect(notifications, 1);
      expect(session.completeMission(1), isFalse);
      expect(notifications, 1);
      expect(session.skipMission(2), isTrue);
      expect(notifications, 2);
    });
  });
}
