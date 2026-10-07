// Ringing mission screen (Phase 4): solve missions to stop the alarm.
//
// Entered only from a native ring launch ([RingingLaunch]); the app boots
// into this screen instead of Home and returns Home-ward via [onFinished]
// after the ring stops. Flow:
//   - Loads the alarm's missions via [MissionService] (loading / error).
//   - No missions (or the load failed): the alarm stays stoppable — a Stop
//     button ends the ring through the existing safe path. A ringing alarm
//     must never strand the user, with or without missions.
//   - Missions present: runs a [MissionSession] strictly in order, showing
//     the current mission's widget, `Mission i / N` progress, an invalid-
//     setup warning when stored rows were skipped, and a Skip button for
//     optional missions only.
//   - When the session completes, the ring stops through
//     [RingingAlarmBridge.stopRingingAlarm] (the native `ACTION_STOP`
//     path, whose post-fire handoff chains the next occurrence as before)
//     and [onFinished] fires. Stop failures show a retry; the ring keeps
//     ringing until a stop succeeds.
//
// Leaving the screen (system Back) never stops the ring: the ongoing
// notification returns the user here. Session progress is transient (held
// by the [MissionSession], never persisted).

import 'dart:math' show Random;

import 'package:alarmx/core/l10n/app_strings.dart';
import 'package:alarmx/core/models/models.dart';
import 'package:alarmx/features/missions/barcode/barcode_mission_widget.dart';
import 'package:alarmx/features/missions/code_scan/code_scan_mission_widget.dart'
    show ScannerViewBuilder;
import 'package:alarmx/features/missions/math/math_mission_widget.dart';
import 'package:alarmx/features/missions/mission_config.dart';
import 'package:alarmx/features/missions/mission_engine.dart';
import 'package:alarmx/features/missions/mission_service.dart';
import 'package:alarmx/features/missions/permissions/camera_permission.dart';
import 'package:alarmx/features/missions/photo/photo_mission.dart';
import 'package:alarmx/features/missions/photo/photo_mission_widget.dart';
import 'package:alarmx/features/missions/qr/qr_mission_widget.dart';
import 'package:alarmx/features/missions/shake/shake_mission.dart';
import 'package:alarmx/features/missions/shake/shake_mission_widget.dart';
import 'package:alarmx/features/missions/typing/typing_mission_widget.dart';
import 'package:flutter/material.dart';

import 'ringing_alarm_bridge.dart';
import 'ringing_launch.dart';

/// Mission-execution overrides for tests. Production uses the live
/// platform sources (real camera/scanner/sensors); every override keeps
/// its widget's production default when `null`.
class MissionTestOverrides {
  const MissionTestOverrides({
    this.permissionGate,
    this.scannerBuilder,
    this.photoSource,
    this.shakeSource,
    this.shakeDetector,
    this.mathRandom,
  });

  final CameraPermissionGate? permissionGate;
  final ScannerViewBuilder? scannerBuilder;
  final PhotoCaptureSource? photoSource;
  final ShakeSensorSource? shakeSource;
  final ShakeDetector? shakeDetector;
  final Random? mathRandom;
}

/// Solves [launch]'s missions to stop the ring; see the file docs.
class RingingMissionScreen extends StatefulWidget {
  const RingingMissionScreen({
    super.key,
    required this.launch,
    required this.missionService,
    required this.bridge,
    required this.onFinished,
    this.overrides = const MissionTestOverrides(),
  });

  final RingingLaunch launch;
  final MissionService missionService;
  final RingingAlarmBridge bridge;

  /// Called after the ring stopped successfully (the host returns Home).
  final VoidCallback onFinished;

  /// Test doubles for mission execution; production uses live sources.
  final MissionTestOverrides overrides;

  @override
  State<RingingMissionScreen> createState() => _RingingMissionScreenState();
}

enum _LoadPhase { loading, error, ready }

class _RingingMissionScreenState extends State<RingingMissionScreen> {
  _LoadPhase _load = _LoadPhase.loading;
  MissionSession? _session;
  int _invalidCount = 0;
  bool _finishing = false;
  bool _stopFailed = false;

  @override
  void initState() {
    super.initState();
    _loadMissions();
  }

  @override
  void dispose() {
    _session?.dispose();
    super.dispose();
  }

  Future<void> _loadMissions() async {
    final AlarmMissions loaded;
    try {
      loaded = await widget.missionService
          .getMissionsForAlarm(widget.launch.alarmId);
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _load = _LoadPhase.error;
      });
      return;
    }
    if (!mounted) {
      return;
    }
    final MissionSession session = MissionSession(loaded.entries)
      ..addListener(_onSession);
    setState(() {
      _session = session;
      _invalidCount = loaded.invalidCount;
      _load = _LoadPhase.ready;
    });
  }

  void _onSession() {
    final MissionSession? session = _session;
    if (!mounted || session == null) {
      return;
    }
    if (session.isComplete && !_finishing && !_stopFailed) {
      _finish();
    } else {
      setState(() {});
    }
  }

  /// Stops the ring through the existing safe path, then finishes.
  /// Failures show a retry; the ring continues until a stop succeeds.
  Future<void> _finish() async {
    if (_finishing) {
      return;
    }
    setState(() {
      _finishing = true;
      _stopFailed = false;
    });
    try {
      await widget.bridge.stopRingingAlarm(widget.launch.alarmId);
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _finishing = false;
        _stopFailed = true;
      });
      return;
    }
    widget.onFinished();
  }

  @override
  Widget build(BuildContext context) {
    final AppStrings strings = AppStrings.of(context);
    final String title = widget.launch.label?.trim().isNotEmpty ?? false
        ? widget.launch.label!.trim()
        : '${strings.appTitle} ${widget.launch.alarmId}';
    return Scaffold(
      appBar: AppBar(title: Text(strings.ringingTitle)),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: _body(strings, title),
        ),
      ),
    );
  }

  Widget _body(AppStrings strings, String title) {
    if (_finishing) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: <Widget>[
              const CircularProgressIndicator(),
              const SizedBox(height: 12),
              Text(strings.ringingStopping),
            ],
          ),
        ),
      );
    }
    if (_stopFailed) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            strings.ringingStopFailed,
            style: Theme.of(context).textTheme.titleMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          FilledButton(
            key: const Key('ringing_retry_button'),
            onPressed: _finish,
            child: Text(strings.missionRetry),
          ),
        ],
      );
    }
    switch (_load) {
      case _LoadPhase.loading:
        return const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: CircularProgressIndicator(),
          ),
        );
      case _LoadPhase.error:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              strings.ringingLoadFailed,
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            FilledButton(
              key: const Key('ringing_stop_button'),
              onPressed: _finish,
              child: Text(strings.ringingStop),
            ),
          ],
        );
      case _LoadPhase.ready:
        break;
    }
    final MissionSession? session = _session;
    if (session == null || session.totalCount == 0) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            title,
            style: Theme.of(context).textTheme.headlineSmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            strings.ringingNoMissions,
            style: Theme.of(context).textTheme.bodyLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          FilledButton(
            key: const Key('ringing_stop_button'),
            onPressed: _finish,
            child: Text(strings.ringingStop),
          ),
        ],
      );
    }
    final MissionEntry? current = session.current;
    if (current == null) {
      // Complete but the stop has not resolved yet (retryable via the
      // stop-failed state once `_finish` reports back).
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(strings.ringingStopping),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          title,
          style: Theme.of(context).textTheme.headlineSmall,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          '${strings.missionProgress} ${session.currentIndex + 1} / ${session.totalCount}',
          key: const Key('ringing_progress_text'),
          style: Theme.of(context).textTheme.titleMedium,
          textAlign: TextAlign.center,
        ),
        if (_invalidCount > 0) ...<Widget>[
          const SizedBox(height: 8),
          Text(
            strings.ringingSkippedInvalid,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.error,
                ),
            textAlign: TextAlign.center,
          ),
        ],
        const SizedBox(height: 16),
        _missionWidget(current),
        if (!current.required) ...<Widget>[
          const SizedBox(height: 12),
          OutlinedButton(
            key: const Key('ringing_skip_button'),
            onPressed: () {
              session.skipMission(current.id);
            },
            child: Text(
              '${strings.missionSkip} (${strings.missionOptional})',
            ),
          ),
        ],
      ],
    );
  }

  Widget _missionWidget(MissionEntry entry) {
    final MissionTestOverrides overrides = widget.overrides;
    final VoidCallback complete = () {
      _session?.completeMission(entry.id);
    };
    switch (entry.type) {
      case MissionType.typing:
        return TypingMissionWidget(
          key: ValueKey<int>(entry.id),
          entry: entry,
          onCompleted: complete,
        );
      case MissionType.qr:
        return QrMissionWidget(
          key: ValueKey<int>(entry.id),
          entry: entry,
          onCompleted: complete,
          permissionGate: overrides.permissionGate ??
              const PermissionHandlerCameraGate(),
          scannerBuilder: overrides.scannerBuilder,
        );
      case MissionType.barcode:
        return BarcodeMissionWidget(
          key: ValueKey<int>(entry.id),
          entry: entry,
          onCompleted: complete,
          permissionGate: overrides.permissionGate ??
              const PermissionHandlerCameraGate(),
          scannerBuilder: overrides.scannerBuilder,
        );
      case MissionType.photo:
        return PhotoMissionWidget(
          key: ValueKey<int>(entry.id),
          entry: entry,
          onCompleted: complete,
          captureSource: overrides.photoSource,
        );
      case MissionType.shake:
        return ShakeMissionWidget(
          key: ValueKey<int>(entry.id),
          entry: entry,
          onCompleted: complete,
          source: overrides.shakeSource ?? const SensorsPlusShakeSource(),
          detector: overrides.shakeDetector,
        );
      case MissionType.math:
        return MathMissionWidget(
          key: ValueKey<int>(entry.id),
          entry: entry,
          onCompleted: complete,
          random: overrides.mathRandom,
        );
      case MissionType.none:
        // Unreachable: the service filters `none` rows before the engine.
        return Text(AppStrings.of(context).ringingSkippedInvalid);
    }
  }
}
