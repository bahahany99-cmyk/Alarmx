// Shake mission logic (Phase 4): deterministic shake detection.
//
// The accelerometer stream (gravity included, ~9.8 m/s^2 at rest) feeds
// [ShakeDetector]: a sample counts as a shake when its magnitude reaches
// [kShakeThresholdMps2] and at least [kShakeDebounce] has passed since the
// previous counted shake, so one physical shake cannot count twice.
// Threshold/debounce live here — never scattered across widgets — and the
// clock is injectable so tests are deterministic.
//
// [ShakeSensorSource] decouples the controller from `sensors_plus`:
// production wires [SensorsPlusShakeSource], tests inject a scripted
// stream. Monitoring starts only while the mission executes and stops on
// completion/disposal; nothing listens globally.

import 'dart:async' show Stream, StreamSubscription;
import 'dart:math' show sqrt;

import 'package:flutter/foundation.dart';
import 'package:sensors_plus/sensors_plus.dart' as sensors;

import '../mission_config.dart';

/// Magnitude (m/s^2, gravity included) a sample must reach to count as a
/// shake. Rests at ~9.8; a deliberate shake peaks well above 15.
const double kShakeThresholdMps2 = 15.0;

/// Minimum gap between two counted shakes.
const Duration kShakeDebounce = Duration(milliseconds: 500);

/// One accelerometer sample (m/s^2, gravity included).
class AccelSample {
  const AccelSample(this.x, this.y, this.z);

  final double x;
  final double y;
  final double z;

  double get magnitude => sqrt(x * x + y * y + z * z);
}

/// Source of accelerometer samples for a shake mission.
abstract class ShakeSensorSource {
  Stream<AccelSample> get samples;
}

/// [ShakeSensorSource] backed by the `sensors_plus` accelerometer stream.
class SensorsPlusShakeSource implements ShakeSensorSource {
  const SensorsPlusShakeSource();

  @override
  Stream<AccelSample> get samples => sensors.accelerometerEvents.map(
        (sensors.AccelerometerEvent event) =>
            AccelSample(event.x, event.y, event.z),
      );
}

/// Counts valid shakes from a sample stream; see the file docs.
class ShakeDetector {
  ShakeDetector({
    this.threshold = kShakeThresholdMps2,
    this.debounce = kShakeDebounce,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final double threshold;
  final Duration debounce;
  final DateTime Function() _clock;
  int _count = 0;
  DateTime? _lastShake;

  int get count => _count;

  /// Feeds one sample. Returns `true` when it counted as a new shake.
  bool feed(AccelSample sample) {
    if (sample.magnitude < threshold) {
      return false;
    }
    final DateTime now = _clock();
    final DateTime? last = _lastShake;
    if (last != null && now.difference(last) < debounce) {
      return false;
    }
    _lastShake = now;
    _count++;
    return true;
  }

  void reset() {
    _count = 0;
    _lastShake = null;
  }
}

/// Owns one shake mission's progress: subscribes to the sensor on [start],
/// counts valid shakes, completes at the required count, and stops the
/// subscription on completion, [stop], or disposal.
///
/// A sensor-stream error raises [sensorFailed] (the mission stays
/// incomplete; the UI offers a retry). Errors never throw out of the
/// controller.
class ShakeMissionController extends ChangeNotifier {
  ShakeMissionController({
    required ShakeMissionConfig config,
    required ShakeSensorSource source,
    ShakeDetector? detector,
  })  : _required = config.requiredCount,
        _source = source,
        _detector = detector ?? ShakeDetector();

  final int _required;
  final ShakeSensorSource _source;
  final ShakeDetector _detector;
  StreamSubscription<AccelSample>? _subscription;
  bool _started = false;
  bool _done = false;
  bool _sensorFailed = false;

  int get progress => _detector.count;

  int get requiredCount => _required;

  bool get isDone => _done;

  bool get sensorFailed => _sensorFailed;

  /// Starts monitoring. Idempotent; safe to call for a retry after
  /// [stop] or a sensor failure.
  void start() {
    if (_started || _done) {
      return;
    }
    _started = true;
    _sensorFailed = false;
    _subscription = _source.samples.listen(
      _onSample,
      onError: (_) {
        _sensorFailed = true;
        _started = false;
        _subscription = null;
        notifyListeners();
      },
      cancelOnError: false,
    );
  }

  void _onSample(AccelSample sample) {
    if (_done) {
      return;
    }
    if (_detector.feed(sample)) {
      if (_detector.count >= _required) {
        _done = true;
        unawaitedStop();
      }
      notifyListeners();
    }
  }

  /// Stops monitoring without completing. Used when the mission screen
  /// goes away before completion.
  Future<void> stop() async {
    _started = false;
    final StreamSubscription<AccelSample>? subscription = _subscription;
    _subscription = null;
    if (subscription != null) {
      try {
        await subscription.cancel();
      } catch (_) {
        // Best effort: a failed cancel must not break teardown.
      }
    }
  }

  /// Sync variant for completion/disposal paths (a no-op when idle).
  void unawaitedStop() {
    _started = false;
    final StreamSubscription<AccelSample>? subscription = _subscription;
    _subscription = null;
    subscription?.cancel();
  }

  @override
  void dispose() {
    unawaitedStop();
    super.dispose();
  }
}
