import 'package:alarmx/core/permissions/settings_bounce_detector.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SettingsBounceDetector', () {
    test('default threshold is 1500ms', () {
      final SettingsBounceDetector detector = SettingsBounceDetector();
      expect(detector.threshold, const Duration(milliseconds: 1500));
    });

    test('resume within threshold reports a bounce', () {
      DateTime now = DateTime(2026, 1, 1);
      final SettingsBounceDetector detector =
          SettingsBounceDetector(clock: () => now);
      detector.arm();
      now = now.add(const Duration(milliseconds: 500));
      expect(detector.consumeResume(), isTrue);
    });

    test('resume after threshold reports no bounce', () {
      DateTime now = DateTime(2026, 1, 1);
      final SettingsBounceDetector detector =
          SettingsBounceDetector(clock: () => now);
      detector.arm();
      now = now.add(const Duration(seconds: 5));
      expect(detector.consumeResume(), isFalse);
    });

    test('resume exactly at threshold reports no bounce', () {
      DateTime now = DateTime(2026, 1, 1);
      final SettingsBounceDetector detector =
          SettingsBounceDetector(clock: () => now);
      detector.arm();
      now = now.add(const Duration(milliseconds: 1500));
      expect(detector.consumeResume(), isFalse);
    });

    test('resume with no armed launch reports no bounce', () {
      final SettingsBounceDetector detector = SettingsBounceDetector();
      expect(detector.consumeResume(), isFalse);
    });

    test('each launch gets exactly one verdict', () {
      DateTime now = DateTime(2026, 1, 1);
      final SettingsBounceDetector detector =
          SettingsBounceDetector(clock: () => now);
      detector.arm();
      now = now.add(const Duration(milliseconds: 100));
      expect(detector.consumeResume(), isTrue);
      expect(detector.consumeResume(), isFalse);
    });

    test('re-arming replaces the pending launch', () {
      DateTime now = DateTime(2026, 1, 1);
      final SettingsBounceDetector detector =
          SettingsBounceDetector(clock: () => now);
      detector.arm();
      now = now.add(const Duration(seconds: 5));
      detector.arm();
      now = now.add(const Duration(milliseconds: 100));
      expect(detector.consumeResume(), isTrue);
    });
  });
}
