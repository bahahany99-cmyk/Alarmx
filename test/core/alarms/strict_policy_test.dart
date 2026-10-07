import 'package:alarmx/core/alarms/strict_policy.dart';
import 'package:flutter_test/flutter_test.dart';

// StrictModePolicy tests: pure stop gate + disable blackout.

void main() {
  group('canStop', () {
    test('non-strict always allows stopping', () {
      expect(
        StrictModePolicy.canStop(
          strictMode: false,
          loadFailed: false,
          totalMissions: 3,
          sessionComplete: false,
        ),
        isTrue,
      );
    });

    test('strict blocks until the session completes', () {
      expect(
        StrictModePolicy.canStop(
          strictMode: true,
          loadFailed: false,
          totalMissions: 2,
          sessionComplete: false,
        ),
        isFalse,
      );
      expect(
        StrictModePolicy.canStop(
          strictMode: true,
          loadFailed: false,
          totalMissions: 2,
          sessionComplete: true,
        ),
        isTrue,
      );
    });

    test('strict with zero missions does not deadlock', () {
      expect(
        StrictModePolicy.canStop(
          strictMode: true,
          loadFailed: false,
          totalMissions: 0,
          sessionComplete: false,
        ),
        isTrue,
      );
    });

    test('failed mission load stays stoppable even when strict', () {
      expect(
        StrictModePolicy.canStop(
          strictMode: true,
          loadFailed: true,
          totalMissions: 0,
          sessionComplete: false,
        ),
        isTrue,
      );
    });
  });

  group('canDisableStrict', () {
    final DateTime now = DateTime(2026, 10, 8, 6, 30);

    test('non-strict alarms are unaffected', () {
      expect(
        StrictModePolicy.canDisableStrict(
          wasStrict: false,
          nextTriggerAt: now.add(const Duration(minutes: 1)),
          now: now,
        ),
        isTrue,
      );
    });

    test('no schedule allows disabling', () {
      expect(
        StrictModePolicy.canDisableStrict(
          wasStrict: true,
          nextTriggerAt: null,
          now: now,
        ),
        isTrue,
      );
    });

    test('past trigger allows disabling', () {
      expect(
        StrictModePolicy.canDisableStrict(
          wasStrict: true,
          nextTriggerAt: now.subtract(const Duration(minutes: 1)),
          now: now,
        ),
        isTrue,
      );
    });

    test('distant trigger allows disabling', () {
      expect(
        StrictModePolicy.canDisableStrict(
          wasStrict: true,
          nextTriggerAt: now.add(const Duration(hours: 2)),
          now: now,
        ),
        isTrue,
      );
      expect(
        StrictModePolicy.canDisableStrict(
          wasStrict: true,
          nextTriggerAt:
              now.add(kStrictDisableBlackout + const Duration(seconds: 1)),
          now: now,
        ),
        isTrue,
      );
    });

    test('imminent trigger refuses disabling', () {
      expect(
        StrictModePolicy.canDisableStrict(
          wasStrict: true,
          nextTriggerAt: now.add(const Duration(minutes: 1)),
          now: now,
        ),
        isFalse,
      );
      expect(
        StrictModePolicy.canDisableStrict(
          wasStrict: true,
          nextTriggerAt: now.add(kStrictDisableBlackout),
          now: now,
        ),
        isFalse,
      );
    });
  });
}
