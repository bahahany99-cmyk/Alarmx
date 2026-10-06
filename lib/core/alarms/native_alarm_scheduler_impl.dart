// Default implementation of [NativeAlarmScheduler] backed by a
// `MethodChannel` to the native Android side.
//
// Channel name: `"com.alarmx.app.alarmx/alarm_scheduler"` (must match
// the one registered in `MainActivity.kt`).
//
// Method names + argument shapes (must match MainActivity.kt):
//   - "scheduleExactAlarm"  args: { "alarmId": int, "triggerAtMillis": long,
//       plus, for persisted alarms, "label": String? and
//       "vibrationEnabled": bool from [AlarmFireConfig] }
//   - "cancelAlarm"         args: { "alarmId": int }
//   - "canScheduleExactAlarms"  args: {}
//
// The `triggerAt` DateTime is serialised to milliseconds since epoch so the
// native side receives a Long (millisecond resolution is what AlarmManager
// expects).

import 'package:flutter/services.dart';

import 'alarm_fire_config.dart';
import 'native_alarm_scheduler.dart';

class NativeAlarmSchedulerImpl implements NativeAlarmScheduler {
  static const MethodChannel _channel =
      MethodChannel('com.alarmx.app.alarmx/alarm_scheduler');

  const NativeAlarmSchedulerImpl();

  /// Schedules a one-shot exact alarm via the native `scheduleExactAlarm`.
  ///
  /// When [fireConfig] is provided its entries are merged into the args
  /// (keys must match the `MainActivity` parser); when omitted the args
  /// stay exactly the legacy two-key map, preserving Phase 1.2 behavior.
  @override
  Future<void> scheduleExactAlarm({
    required int alarmId,
    required DateTime triggerAt,
    AlarmFireConfig? fireConfig,
  }) async {
    final Map<String, Object?> args = <String, Object?>{
      'alarmId': alarmId,
      'triggerAtMillis': triggerAt.millisecondsSinceEpoch,
    };
    if (fireConfig != null) {
      args.addAll(fireConfig.toMap());
    }
    await _channel.invokeMethod<void>('scheduleExactAlarm', args);
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
