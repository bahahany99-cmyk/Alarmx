// Default implementation of [NativeAlarmScheduler] backed by a
// `MethodChannel` to the native Android side.
//
// Channel name: `"com.alarmx.app.alarmx/alarm_scheduler"` (must match
// the one registered in `MainActivity.kt`).
//
// Method names + argument shapes (must match MainActivity.kt):
//   - "scheduleExactAlarm"  args: { "alarmId": int, "triggerAtMillis": long }
//   - "cancelAlarm"         args: { "alarmId": int }
//   - "canScheduleExactAlarms"  args: {}
//
// The `triggerAt` DateTime is serialised to milliseconds since epoch so the
// native side receives a Long (millisecond resolution is what AlarmManager
// expects).

import 'package:flutter/services.dart';

import 'native_alarm_scheduler.dart';

class NativeAlarmSchedulerImpl implements NativeAlarmScheduler {
  static const MethodChannel _channel =
      MethodChannel('com.alarmx.app.alarmx/alarm_scheduler');

  const NativeAlarmSchedulerImpl();

  @override
  Future<void> scheduleExactAlarm({
    required int alarmId,
    required DateTime triggerAt,
  }) async {
    await _channel.invokeMethod<void>(
      'scheduleExactAlarm',
      <String, Object?>{
        'alarmId': alarmId,
        'triggerAtMillis': triggerAt.millisecondsSinceEpoch,
      },
    );
  }

  @override
  Future<void> cancelAlarm({required int alarmId}) async {
    await _channel.invokeMethod<void>(
      'cancelAlarm',
      <String, Object?>{'alarmId': alarmId},
    );
  }

  @override
  Future<bool> canScheduleExactAlarms() async {
    final result =
        await _channel.invokeMethod<bool>('canScheduleExactAlarms');
    return result ?? false;
  }
}
