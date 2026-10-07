// Tests for RingingLaunch parsing: valid, partial, and malformed
// native payloads (malformed degrades to null, never throws).

import 'package:alarmx/features/ringing_alarm/ringing_launch.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('RingingLaunch.tryParse', () {
    test('parses a full payload', () {
      final RingingLaunch? launch = RingingLaunch.tryParse(
        <String, Object?>{
          'alarmId': 7,
          'label': 'Morning',
          'triggerAtMillis': 1728211200000,
        },
      );
      expect(launch, isNotNull);
      expect(launch!.alarmId, 7);
      expect(launch.label, 'Morning');
      expect(launch.triggerAtMillis, 1728211200000);
    });

    test('parses a minimal payload', () {
      final RingingLaunch? launch = RingingLaunch.tryParse(
        <String, Object?>{'alarmId': 3},
      );
      expect(launch, isNotNull);
      expect(launch!.alarmId, 3);
      expect(launch.label, isNull);
      expect(launch.triggerAtMillis, isNull);
    });

    test('wrong-typed optionals degrade to null', () {
      final RingingLaunch? launch = RingingLaunch.tryParse(
        <String, Object?>{
          'alarmId': 3,
          'label': 42,
          'triggerAtMillis': 'soon',
        },
      );
      expect(launch, isNotNull);
      expect(launch!.label, isNull);
      expect(launch.triggerAtMillis, isNull);
    });

    test('malformed payloads yield null', () {
      const List<Object?> bad = <Object?>[
        null,
        'junk',
        42,
        <Object?>[],
        <String, Object?>{},
        <String, Object?>{'alarmId': 'seven'},
        <String, Object?>{'alarmId': -1},
        <String, Object?>{'alarmId': 1.5},
        <String, Object?>{'label': 'x'},
      ];
      for (final Object? args in bad) {
        expect(RingingLaunch.tryParse(args), isNull, reason: '$args');
      }
    });
  });
}
