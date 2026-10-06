// Thin native -> Dart event listener for the alarm pipeline.
//
// This is the reverse direction of [NativeAlarmScheduler] over the SAME
// `MethodChannel` (`"com.alarmx.app.alarmx/alarm_scheduler"`, must match
// `MainActivity.kt`): after a persisted alarm stops ringing, the native
// service best-effort delivers:
//
//   `onAlarmStopped` args: `{ "alarmId": int, "triggerAtMillis": long }`
//
// The host (currently the temporary test screen; the real app shell later)
// attaches a listener and routes the event to
// `AlarmSchedulingCoordinator.rescheduleAfterFire`. Delivery needs a live
// engine at stop time; when the process has none, the stop is simply not
// reported and ringing is unaffected — the stored `nextTriggerAt` still
// names the fired trigger, which is the breadcrumb the future boot
// reconciler will use. Malformed calls are ignored, never thrown.

import 'package:flutter/services.dart';

/// Listens for post-fire stop reports from the native ringing service.
class NativeAlarmEvents {
  /// Shared channel with [NativeAlarmSchedulerImpl] (opposite direction).
  static const MethodChannel _channel =
      MethodChannel('com.alarmx.app.alarmx/alarm_scheduler');

  /// Called with the database alarm id and the fired trigger it just
  /// finished ringing for. The handler typically delegates to the
  /// scheduling coordinator; it must be safe to call more than once for
  /// the same trigger (the coordinator rejects repeats as stale).
  Future<void> Function(int alarmId, DateTime firedTriggerAt)?
      onAlarmStopped;

  /// Starts receiving native events. Safe to call more than once.
  void attach() {
    _channel.setMethodCallHandler(_handleCall);
  }

  /// Stops receiving native events.
  void detach() {
    _channel.setMethodCallHandler(null);
  }

  Future<void> _handleCall(MethodCall call) async {
    if (call.method != 'onAlarmStopped') {
      return;
    }
    final Object? rawArgs = call.arguments;
    if (rawArgs is! Map) {
      return;
    }
    final Map<String, Object?> args = Map<String, Object?>.from(rawArgs);
    final Object? rawId = args['alarmId'];
    final Object? rawMillis = args['triggerAtMillis'];
    if (rawId is! int || rawMillis is! int) {
      return;
    }
    final Future<void> Function(int alarmId, DateTime firedTriggerAt)?
        handler = onAlarmStopped;
    if (handler == null) {
      return;
    }
    await handler(rawId, DateTime.fromMillisecondsSinceEpoch(rawMillis));
  }
}
