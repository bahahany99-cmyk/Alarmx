// Light mission logic: catch bright light, or guide the glow dot.
//
// Two modes (see [LightMode]):
//   - Light Catch ([LightCatchController]): the mission completes when a
//     sensor sample reaches [kLightCatchTargetLux]. Sampling is explicit
//     ([sample], driven by the widget's timer) so tests stay
//     deterministic without fake async. A null reading means the device
//     has no usable sensor: [needsFallback] latches and the mission can
//     never complete in this mode — the widget then offers Glow Dot for
//     this execution instead.
//   - Glow Dot ([GlowDotController]): positions are normalized (0..1)
//     points so the controller is resolution-independent; the widget maps
//     drags into this space. The mission completes when the dot is
//     released/moved within [snapRadius] of the socket and snaps in.

import 'dart:ui' show Offset;

import 'package:alarmx/features/missions/light/light_sensor_gate.dart';
import 'package:flutter/foundation.dart';

/// Lux a Light Catch sample must reach. Dim indoor rooms read ~50-150,
/// bright indoor light ~300-500, outdoors thousands: 400 needs a
/// deliberate bright light without demanding sunlight.
const double kLightCatchTargetLux = 400;

/// How often the Light Catch widget samples while active.
const Duration kLightCatchPollInterval = Duration(milliseconds: 500);

/// Owns one Light Catch mission's progress; see the file docs.
class LightCatchController extends ChangeNotifier {
  LightCatchController({required LightSensorGate gate}) : _gate = gate;

  final LightSensorGate _gate;
  double? _lux;
  bool _sampling = false;
  bool _noSensor = false;
  bool _done = false;

  /// Latest reading in lux (null before the first sample).
  double? get lux => _lux;

  /// Latched when a sample reports no usable sensor.
  bool get needsFallback => _noSensor;

  bool get isDone => _done;

  /// 0..1 progress toward the target (0 before the first sample).
  double get progress {
    final double? reading = _lux;
    if (reading == null) {
      return 0;
    }
    return (reading / kLightCatchTargetLux).clamp(0.0, 1.0);
  }

  /// Takes one sample. Concurrent calls collapse into the in-flight
  /// sample; calls after [isDone] or [needsFallback] are no-ops.
  Future<void> sample() async {
    if (_sampling || _done || _noSensor) {
      return;
    }
    _sampling = true;
    final double? reading;
    try {
      reading = await _gate.readLux();
    } catch (_) {
      // Defensive: the gate contract is never-throw, but a custom
      // implementation must not crash the mission either; treat as
      // "no reading yet" so sampling continues.
      _sampling = false;
      return;
    }
    _sampling = false;
    if (_done) {
      return;
    }
    if (reading == null) {
      _noSensor = true;
      notifyListeners();
      return;
    }
    _lux = reading;
    if (reading >= kLightCatchTargetLux) {
      _done = true;
    }
    notifyListeners();
  }
}

/// Owns one Glow Dot mission's progress; see the file docs.
class GlowDotController extends ChangeNotifier {
  GlowDotController({
    this.dot = const Offset(0.2, 0.75),
    this.socket = const Offset(0.8, 0.25),
    this.snapRadius = 0.12,
  });

  /// Current dot center in normalized coordinates.
  Offset dot;

  /// Socket center in normalized coordinates.
  final Offset socket;

  /// Normalized distance within which the dot snaps in and completes.
  final double snapRadius;

  bool _done = false;

  bool get isDone => _done;

  /// Moves the dot to [position] (normalized, clamped to 0..1),
  /// completing when it lands within [snapRadius] of the socket.
  /// Calls after [isDone] are no-ops.
  void move(Offset position) {
    if (_done) {
      return;
    }
    final Offset clamped = Offset(
      position.dx.clamp(0.0, 1.0),
      position.dy.clamp(0.0, 1.0),
    );
    dot = clamped;
    if ((clamped - socket).distance <= snapRadius) {
      dot = socket;
      _done = true;
    }
    notifyListeners();
  }
}
