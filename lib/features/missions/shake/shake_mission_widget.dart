// Shake mission widget (Phase 4): shake the phone N times.
//
// Renders a [ShakeMissionController]: the instruction, big `n / N`
// progress, and a sensor-error state with a retry. Monitoring starts when
// the mission appears and stops on completion/disposal; completion is
// reported exactly once.

import 'package:alarmx/core/l10n/app_strings.dart';
import 'package:alarmx/features/missions/mission_config.dart';
import 'package:alarmx/features/missions/shake/shake_mission.dart';
import 'package:flutter/material.dart';

/// Executes one shake [entry], calling [onCompleted] once on success.
class ShakeMissionWidget extends StatefulWidget {
  const ShakeMissionWidget({
    super.key,
    required this.entry,
    required this.onCompleted,
    this.source = const SensorsPlusShakeSource(),
    this.detector,
  });

  final MissionEntry entry;
  final VoidCallback onCompleted;

  /// Sensor-source override for tests; production uses the accelerometer.
  final ShakeSensorSource source;

  /// Detector override for tests (deterministic clock); production uses
  /// the default thresholds with wall-clock time.
  final ShakeDetector? detector;

  @override
  State<ShakeMissionWidget> createState() => _ShakeMissionWidgetState();
}

class _ShakeMissionWidgetState extends State<ShakeMissionWidget> {
  late final ShakeMissionController _mission;
  bool _reported = false;

  @override
  void initState() {
    super.initState();
    final MissionConfig raw = widget.entry.config;
    _mission = ShakeMissionController(
      config: raw is ShakeMissionConfig
          ? raw
          : const ShakeMissionConfig(1),
      source: widget.source,
      detector: widget.detector,
    );
    _mission.addListener(_onProgress);
    _mission.start();
  }

  @override
  void dispose() {
    _mission.removeListener(_onProgress);
    _mission.dispose();
    super.dispose();
  }

  void _onProgress() {
    if (_mission.isDone && !_reported) {
      _reported = true;
      widget.onCompleted();
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppStrings strings = AppStrings.of(context);
    if (widget.entry.config is! ShakeMissionConfig) {
      return Text(strings.ringingSkippedInvalid);
    }
    final ThemeData theme = Theme.of(context);
    return ListenableBuilder(
      listenable: _mission,
      builder: (BuildContext context, Widget? _) {
        if (_mission.sensorFailed) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(
                strings.sensorUnavailable,
                style: theme.textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                strings.permissionSensorMessage,
                style: theme.textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              FilledButton(
                key: const Key('shake_retry_button'),
                onPressed: _mission.start,
                child: Text(strings.missionRetry),
              ),
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              strings.shakeInstruction,
              style: theme.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  _mission.isDone
                      ? strings.missionCompleted
                      : '${_mission.progress} / ${_mission.requiredCount}',
                  key: const Key('shake_progress_text'),
                  style: theme.textTheme.headlineMedium,
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
