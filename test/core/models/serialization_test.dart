import 'package:alarmx/core/database/database.dart';
import 'package:flutter_test/flutter_test.dart';

// The entity classes are Drift's generated immutable row classes. These tests
// lock in their `toJson`/`fromJson` round-trip behavior, which the app relies
// on for configuration snapshots and future backup/restore.

void main() {
  group('Alarm serialization', () {
    test('toJson/fromJson round-trip', () {
      final DateTime now = DateTime(2026, 10, 6, 7, 30);
      final Alarm alarm = Alarm(
        id: 1,
        label: 'Morning',
        hour: 7,
        minute: 30,
        enabled: true,
        repeatType: 'daily',
        repeatDays: null,
        onceDate: null,
        soundUri: null,
        soundType: 'default',
        volume: 80,
        fadeInEnabled: false,
        vibrationEnabled: true,
        snoozeEnabled: true,
        snoozeMinutes: 5,
        snoozeMaxCount: 3,
        strictMode: false,
        nextTriggerAt: null,
        createdAt: now,
        updatedAt: now,
      );
      final Map<String, dynamic> json = alarm.toJson();
      final Alarm decoded = Alarm.fromJson(json);
      expect(decoded, alarm);
    });
  });

  group('Mission serialization', () {
    test('toJson/fromJson round-trip', () {
      const Mission mission = Mission(
        id: 2,
        alarmId: 1,
        type: 'math',
        orderIndex: 0,
        configJson: '{"count":3}',
        required: true,
      );
      final Map<String, dynamic> json = mission.toJson();
      final Mission decoded = Mission.fromJson(json);
      expect(decoded, mission);
    });
  });

  group('AlarmHistoryData serialization', () {
    test('toJson/fromJson round-trip', () {
      final DateTime started = DateTime(2026, 10, 6, 7, 30);
      final DateTime stopped = DateTime(2026, 10, 6, 7, 31);
      final AlarmHistoryData entry = AlarmHistoryData(
        id: 3,
        alarmId: 1,
        startedAt: started,
        stoppedAt: stopped,
        result: 'success',
        attempts: 1,
        snoozeCount: 0,
      );
      final Map<String, dynamic> json = entry.toJson();
      final AlarmHistoryData decoded = AlarmHistoryData.fromJson(json);
      expect(decoded, entry);
    });
  });

  group('AppSetting serialization', () {
    test('toJson/fromJson round-trip', () {
      const AppSetting settings = AppSetting(
        id: 1,
        strictModeDefault: false,
        pinEnabled: false,
        pinHash: null,
        defaultSound: null,
        defaultVolume: 80,
        language: 'ar',
        theme: 'system',
      );
      final Map<String, dynamic> json = settings.toJson();
      final AppSetting decoded = AppSetting.fromJson(json);
      expect(decoded, settings);
    });
  });
}
