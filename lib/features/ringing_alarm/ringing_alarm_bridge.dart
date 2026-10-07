// Bridge to the native ringing pipeline (Phase 4).
//
// Two methods on the shared `\"com.alarmx.app.alarmx/alarm_scheduler\"`
// channel (handled natively next to the scheduler methods):
//   - `getRingingLaunch` (args `{}`): returns the pending Flutter ring
//     launch `{alarmId, label?, triggerAtMillis?}` exactly once (native
//     consumes it on read), or `null` for a normal app start.
//   - `stopRingingAlarm` (args `{alarmId}`): stops the ring through the
//     existing service `ACTION_STOP` path (ringtone/vibration off,
//     notification removed, post-fire handoff to Dart). Idempotent.
//
// The bridge is injected, so the ringing screen and the app shell are
// testable with a fake and CI never touches MethodChannels.

import 'package:flutter/services.dart';

import 'ringing_launch.dart';

/// Native ringing-pipeline bridge; see the file docs.
abstract class RingingAlarmBridge {
  /// Reads (and consumes) the pending ring launch, or `null` for a normal
  /// start. Never throws: channel errors degrade to `null`.
  Future<RingingLaunch?> consumeRingingLaunch();

  /// Stops the ringing alarm through the existing safe native path.
  /// Errors propagate so the caller can show a retry (a failed stop must
  /// never look like a success).
  Future<void> stopRingingAlarm(int alarmId);
}

/// [RingingAlarmBridge] over the shared scheduler MethodChannel.
class MethodChannelRingingBridge implements RingingAlarmBridge {
  MethodChannelRingingBridge([MethodChannel? channel])
      : _channel = channel ??
            const MethodChannel('com.alarmx.app.alarmx/alarm_scheduler');

  final MethodChannel _channel;

  @override
  Future<RingingLaunch?> consumeRingingLaunch() async {
    try {
      final Object? result =
          await _channel.invokeMethod<Object?>('getRingingLaunch');
      if (result == null) {
        return null;
      }
      return RingingLaunch.tryParse(result);
    } catch (_) {
      // No native side (tests, hosted contexts) or a malformed reply:
      // boot normally instead of crashing the launch.
      return null;
    }
  }

  @override
  Future<void> stopRingingAlarm(int alarmId) {
    return _channel.invokeMethod<void>(
      'stopRingingAlarm',
      <String, Object?>{'alarmId': alarmId},
    );
  }
}
