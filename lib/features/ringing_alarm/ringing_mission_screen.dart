// Ringing mission screen (Phase 5): missions, snooze, strict stop, exit.
//
// Entered only from a native ring launch ([RingingLaunch]); the app boots
// into this screen instead of Home and returns Home-ward via [onFinished]
// after the ring reaches a terminal outcome. A [RingingSession] owns the
// load and every terminal action; this screen only renders its state:
//
//   - Missions run strictly in order (the Phase 4 widgets, reused as-is)
//     with `Mission i / N` progress, an invalid-setup warning, and a Skip
//     button for optional missions only. Mission success auto-stops.
//   - Stop is always shown but strict-gated by the session: a strict ring
//     with pending required missions cannot stop normally (the lock and
//     its caption say so); the gate lives in the session, so no UI path
//     can bypass it. Non-strict rings stop on demand.
//   - Snooze (when offered) defers the ring through the existing
//     coordinator pipeline and finishes; failures show a retry that never
//     schedules twice.
//   - Emergency Exit is visually distinct and deliberate: a 10-second
//     hold (with progress) or the PIN when one is enabled. It stops this
//     ring only and never touches the alarm row, future occurrences, or
//     Strict Mode; the episode records `emergency_stop`.
//
// Leaving the screen (system Back) never stops the ring: the ongoing
// notification returns the user here. Session progress is transient.

import 'dart:async' show Timer;
import 'dart:math' show Random;

import 'package:alarmx/core/l10n/app_strings.dart';
import 'package:alarmx/core/models/models.dart';
import 'package:alarmx/core/repositories/alarm_history_repository.dart';
import 'package:alarmx/core/repositories/alarm_repository.dart';
import 'package:alarmx/core/scheduling/alarm_scheduling_coordinator.dart';
import 'package:alarmx/core/security/pin_service.dart';
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
import 'package:alarmx/features/security/pin_prompt.dart';
import 'package:flutter/material.dart';

import 'ringing_alarm_bridge.dart';
import 'ringing_launch.dart';
import 'ringing_session.dart';

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

/// Serves [launch]'s ring to a terminal outcome; see the file docs.
class RingingMissionScreen extends StatefulWidget {
  const RingingMissionScreen({
    super.key,
    required this.launch,
    required this.alarms,
    required this.missionService,
    required this.history,
    required this.coordinator,
    required this.pinService,
    required this.bridge,
    required this.onFinished,
    this.overrides = const MissionTestOverrides(),
  });

  final RingingLaunch launch;
  final AlarmRepository alarms;
  final MissionService missionService;
  final AlarmHistoryRepository history;
  final AlarmSchedulingCoordinator coordinator;
  final PinService pinService;
  final RingingAlarmBridge bridge;

  /// Called once after the ring reaches a terminal outcome.
  final VoidCallback onFinished;

  /// Test doubles for mission execution; production uses live sources.
  final MissionTestOverrides overrides;

  @override
  State<RingingMissionScreen> createState() => _RingingMissionScreenState();
}

/// Which terminal action failed (drives the retry button).
enum _RingAction { stop, snooze, emergency }

class _RingingMissionScreenState extends State<RingingMissionScreen> {
  /// Deliberate-hold length for the Emergency Exit button.
  static const Duration _holdRequired = Duration(seconds: 10);

  late final RingingSession _ringing = RingingSession(
    launch: widget.launch,
    alarms: widget.alarms,
    missions: widget.missionService,
    history: widget.history,
    coordinator: widget.coordinator,
    bridge: widget.bridge,
  );

  /// True once a terminal outcome was reported to the host. Renders a
  /// static done state (not a spinner) so the tree settles while the
  /// host navigates away.
  bool _reported = false;
  _RingAction _lastAction = _RingAction.stop;
  bool _pinEnabled = false;

  /// Emergency-hold progress ticker (`null` while not holding).
  Timer? _holdTicker;
  Duration _holdElapsed = Duration.zero;

  bool get _holding => _holdTicker != null;

  @override
  void initState() {
    super.initState();
    _ringing.addListener(_onRinging);
    _ringing.load();
    _loadPin();
  }

  @override
  void dispose() {
    _holdTicker?.cancel();
    _holdTicker = null;
    _ringing.removeListener(_onRinging);
    _ringing.dispose();
    super.dispose();
  }

  Future<void> _loadPin() async {
    final bool enabled;
    try {
      enabled = await widget.pinService.isPinEnabled();
    } catch (_) {
      return;
    }
    if (mounted) {
      setState(() {
        _pinEnabled = enabled;
      });
    }
  }

  void _onRinging() {
    if (!mounted) {
      return;
    }
    if (_ringing.outcome != RingingOutcome.none && !_reported) {
      _reported = true;
      setState(() {});
      widget.onFinished();
      return;
    }
    setState(() {});
  }

  Future<void> _doStop() async {
    _lastAction = _RingAction.stop;
    await _ringing.stop();
  }

  Future<void> _doSnooze() async {
    _lastAction = _RingAction.snooze;
    await _ringing.snooze();
  }

  Future<void> _doEmergency() async {
    _lastAction = _RingAction.emergency;
    await _ringing.emergencyExit();
  }

  Future<void> _retry() async {
    switch (_lastAction) {
      case _RingAction.stop:
        await _ringing.stop();
      case _RingAction.snooze:
        await _ringing.snooze();
      case _RingAction.emergency:
        await _ringing.emergencyExit();
    }
  }

  /// PIN path for Emergency Exit (offered when a PIN is enabled).
  Future<void> _emergencyWithPin() async {
    if (_ringing.isBusy || _ringing.outcome != RingingOutcome.none) {
      return;
    }
    final AppStrings strings = AppStrings.of(context);
    final String? pin = await showPinPrompt(
      context,
      title: strings.emergencyUsePin,
    );
    if (pin == null || !mounted) {
      return;
    }
    final bool ok;
    try {
      ok = await widget.pinService.verifyPin(pin);
    } catch (_) {
      return;
    }
    if (!mounted) {
      return;
    }
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(strings.msgPinIncorrect)),
      );
      return;
    }
    await _doEmergency();
  }

  /// Starts the deliberate 10-second emergency hold.
  void _beginHold() {
    if (_ringing.isBusy ||
        _ringing.outcome != RingingOutcome.none ||
        _holdTicker != null) {
      return;
    }
    setState(() {
      _holdElapsed = Duration.zero;
    });
    _holdTicker =
        Timer.periodic(const Duration(milliseconds: 100), (Timer tick) {
      if (!mounted) {
        tick.cancel();
        return;
      }
      final Duration next =
          _holdElapsed + const Duration(milliseconds: 100);
      if (next >= _holdRequired) {
        tick.cancel();
        _holdTicker = null;
        setState(() {
          _holdElapsed = _holdRequired;
        });
        _doEmergency();
        return;
      }
      setState(() {
        _holdElapsed = next;
      });
    });
  }

  /// Cancels the emergency hold (finger lifted early).
  void _cancelHold() {
    final Timer? ticker = _holdTicker;
    _holdTicker = null;
    ticker?.cancel();
    if (mounted &&
        _holdElapsed > Duration.zero &&
        _ringing.outcome == RingingOutcome.none) {
      setState(() {
        _holdElapsed = Duration.zero;
      });
    }
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
    switch (_ringing.outcome) {
      case RingingOutcome.stopped:
        return _done(strings.missionCompleted);
      case RingingOutcome.snoozed:
        return _done(strings.ringingSnoozed);
      case RingingOutcome.emergency:
        return _done(strings.ringingEmergencyDone);
      case RingingOutcome.none:
        break;
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (_ringing.isLoading)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: CircularProgressIndicator(),
            ),
          )
        else if (_ringing.errorKey != null)
          _error(strings)
        else
          ..._ready(strings, title),
        const SizedBox(height: 24),
        _emergencyCard(strings),
      ],
    );
  }

  /// Static terminal state; the host navigates away on [onFinished].
  Widget _done(String text) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          text,
          style: Theme.of(context).textTheme.titleMedium,
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  Widget _error(AppStrings strings) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          strings.text(_ringing.errorKey!),
          style: Theme.of(context).textTheme.titleMedium,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        FilledButton(
          key: const Key('ringing_retry_button'),
          onPressed: _retry,
          child: Text(strings.missionRetry),
        ),
      ],
    );
  }

  List<Widget> _ready(AppStrings strings, String title) {
    final MissionSession? session = _ringing.missionSession;
    final ThemeData theme = Theme.of(context);
    return <Widget>[
      Text(
        title,
        style: theme.textTheme.headlineSmall,
        textAlign: TextAlign.center,
      ),
      const SizedBox(height: 8),
      if (session == null || session.totalCount == 0)
        Text(
          _ringing.loadFailed
              ? strings.ringingLoadFailed
              : strings.ringingNoMissions,
          style: theme.textTheme.bodyLarge,
          textAlign: TextAlign.center,
        )
      else ...<Widget>[
        Text(
          '${strings.missionProgress} ${session.currentIndex + 1} / ${session.totalCount}',
          key: const Key('ringing_progress_text'),
          style: theme.textTheme.titleMedium,
          textAlign: TextAlign.center,
        ),
        if (_ringing.invalidMissionCount > 0) ...<Widget>[
          const SizedBox(height: 8),
          Text(
            strings.ringingSkippedInvalid,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.error,
            ),
            textAlign: TextAlign.center,
          ),
        ],
        const SizedBox(height: 16),
        _missionSection(strings, session),
      ],
      const SizedBox(height: 16),
      if (_ringing.isBusy)
        Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: <Widget>[
              const CircularProgressIndicator(),
              const SizedBox(height: 12),
              Text(strings.ringingStopping),
            ],
          ),
        )
      else ...<Widget>[
        FilledButton(
          key: const Key('ringing_stop_button'),
          onPressed: _ringing.canStop ? _doStop : null,
          child: Text(strings.ringingStop),
        ),
        if (_ringing.strictMode && !_ringing.canStop) ...<Widget>[
          const SizedBox(height: 8),
          Text(
            strings.ringingStrictLocked,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.error,
            ),
            textAlign: TextAlign.center,
          ),
        ],
        if (_ringing.canSnooze) ...<Widget>[
          const SizedBox(height: 8),
          OutlinedButton(
            key: const Key('ringing_snooze_button'),
            onPressed: _doSnooze,
            child: Text(strings.ringingSnooze),
          ),
          if (_ringing.snoozesRemaining != null) ...<Widget>[
            const SizedBox(height: 4),
            Text(
              '${strings.ringingSnoozesLeft}: ${_ringing.snoozesRemaining}',
              style: theme.textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ],
    ];
  }

  /// Current mission widget + optional skip; mirrors the Phase 4 flow.
  Widget _missionSection(AppStrings strings, MissionSession session) {
    final MissionEntry? current = session.current;
    if (current == null) {
      // Complete but the stop has not resolved yet (retryable via the
      // stop-failed state once the session reports back).
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

  /// Deliberate, visually distinct Emergency Exit; always available
  /// until a terminal outcome (even while loading or on errors).
  Widget _emergencyCard(AppStrings strings) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;
    final Duration remaining = _holdRequired - _holdElapsed;
    final int shown = remaining.inSeconds < 1 ? 1 : remaining.inSeconds;
    return Card(
      shape: RoundedRectangleBorder(
        side: BorderSide(color: colors.error, width: 2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Icon(Icons.warning_outlined, color: colors.error),
                const SizedBox(width: 8),
                Text(
                  strings.emergencyTitle,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: colors.error,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              strings.emergencyCaption,
              style: theme.textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            GestureDetector(
              onLongPressStart: (_) => _beginHold(),
              onLongPressEnd: (_) => _cancelHold(),
              onLongPressCancel: _cancelHold,
              child: OutlinedButton(
                key: const Key('emergency_hold_button'),
                // Taps are inert by design; only the 10-second hold (or
                // the PIN path below) triggers the exit.
                onPressed: () {},
                style: OutlinedButton.styleFrom(
                  foregroundColor: colors.error,
                  side: BorderSide(color: colors.error),
                ),
                child: Text(
                  _holding
                      ? '$shown'
                      : strings.emergencyHold,
                ),
              ),
            ),
            if (_holding) ...<Widget>[
              const SizedBox(height: 8),
              LinearProgressIndicator(
                key: const Key('emergency_progress'),
                value: _holdElapsed.inMilliseconds /
                    _holdRequired.inMilliseconds,
              ),
            ],
            if (_pinEnabled) ...<Widget>[
              const SizedBox(height: 8),
              TextButton(
                key: const Key('emergency_pin_button'),
                onPressed:
                    _ringing.isBusy ? null : _emergencyWithPin,
                child: Text(strings.emergencyUsePin),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _missionWidget(MissionEntry entry) {
    final MissionTestOverrides overrides = widget.overrides;
    final VoidCallback complete = () {
      _ringing.missionSession?.completeMission(entry.id);
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
