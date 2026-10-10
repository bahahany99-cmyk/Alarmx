// Ambient-light sensor gate for the Light Catch mission.
//
// Readings are polled ONLY while the mission executes (the widget owns a
// periodic timer; the native side registers a listener per sample and
// unregisters immediately). The read lives behind [LightSensorGate] so
// the controller is unit-testable with scripted lux and CI never touches
// platform sensor APIs.
//
// Contract: [readLux] returns the ambient light in lux, or null when the
// device has no light sensor, no sample arrives, or the platform fails.
// Never throws: platform errors degrade to null.

import 'package:flutter/services.dart';

/// Reads the ambient-light sensor for a running Light Catch mission.
abstract class LightSensorGate {
  /// One ambient-light reading in lux, or null when unavailable. Never
  /// throws.
  Future<double?> readLux();
}

/// [LightSensorGate] over the shared alarm-scheduler channel.
class MethodChannelLightSensor implements LightSensorGate {
  const MethodChannelLightSensor([MethodChannel? channel])
      : _channel = channel ??
            const MethodChannel('com.alarmx.app.alarmx/alarm_scheduler');

  final MethodChannel _channel;

  @override
  Future<double?> readLux() async {
    try {
      final Object? reply =
          await _channel.invokeMethod<Object?>('getAmbientLightLux');
      if (reply is double) {
        return reply;
      }
      if (reply is int) {
        return reply.toDouble();
      }
      return null;
    } catch (_) {
      return null;
    }
  }
}
