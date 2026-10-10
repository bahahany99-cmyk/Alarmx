// First-run permission onboarding: one permission per screen.
//
// Shown on first launch until the flow completes to the end (tracked by
// [OnboardingRepository], so reinstalls and cleared app data restart it).
// Steps run in fixed product order: notifications, exact alarms,
// full-screen intent, boot reliability, battery optimization (skippable).
//
// Detection reuses the exact Permission Center paths: [PermissionSnapshot]
// from the settings bridge, judged per step. Actions reuse the bridge's
// settings targets; only notifications uses a runtime dialog (the sole
// runtime permission here, API 33+), via [NotificationPermissionGate].
// Returning from Settings (or the dialog) re-reads state: a step that
// became granted auto-advances, a step granted on arrival offers Continue,
// and a step whose settings page bounced (shared bounce detector) offers
// the app-info page instead of silently re-showing the broken redirect.

import 'package:alarmx/core/l10n/app_strings.dart';
import 'package:alarmx/core/permissions/capability_state.dart';
import 'package:alarmx/core/permissions/permission_bridge.dart';
import 'package:alarmx/core/permissions/permission_snapshot.dart';
import 'package:alarmx/core/permissions/settings_bounce_detector.dart';
import 'package:alarmx/core/repositories/onboarding_repository.dart';
import 'package:alarmx/features/onboarding/notification_permission_gate.dart';
import 'package:flutter/material.dart';

/// Onboarding steps in fixed product order.
enum OnboardingStep { notifications, exactAlarm, fullScreen, boot, battery }

/// First-run permission flow; see the file docs.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({
    super.key,
    required this.bridge,
    required this.notificationGate,
    required this.onboarding,
    required this.onFinished,
    this.clock,
  });

  final PermissionSystemBridge bridge;
  final NotificationPermissionGate notificationGate;
  final OnboardingRepository onboarding;
  final VoidCallback onFinished;

  /// Clock for bounce timing; defaults to [DateTime.now]. Tests pass a
  /// scripted clock.
  final DateTime Function()? clock;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with WidgetsBindingObserver {
  /// Current step; null while the first snapshot loads.
  OnboardingStep? _step;

  /// Latest snapshot; null while loading or when the last read failed
  /// (the step keeps rendering from the previous one).
  PermissionSnapshot? _snapshot;

  /// True once the flow reached the completion screen.
  bool _completed = false;

  /// True while a dialog or settings launch is in flight.
  bool _busy = false;

  /// True when the current step's last settings visit bounced while the
  /// step stayed unsatisfied: an app-info fallback is offered.
  bool _bounced = false;

  int _refreshToken = 0;

  late final SettingsBounceDetector _bounceDetector =
      SettingsBounceDetector(clock: widget.clock);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _enterFlow();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _onResumed();
    }
  }

  /// Flow entry: reads state and lands on the first step needing a screen.
  /// Steps already granted show Continue; N/A steps (permission does not
  /// exist on this OS) are skipped silently — nothing can grant them.
  Future<void> _enterFlow() async {
    final PermissionSnapshot? snapshot = await _readSnapshot();
    if (!mounted) {
      return;
    }
    setState(() {
      _snapshot = snapshot ?? _snapshot;
      _step = OnboardingStep.notifications;
    });
    _skipNotApplicable();
  }

  /// Advances past steps whose permission does not exist on this OS.
  void _skipNotApplicable() {
    var step = _step;
    while (step != null && _isNotApplicable(step, _snapshot)) {
      step = _nextStep(step);
    }
    if (step == null) {
      _complete();
      return;
    }
    if (step != _step && mounted) {
      setState(() {
        _step = step;
      });
    }
  }

  /// Resume verdict: judges the bounce, re-reads state, auto-advances a
  /// step that became granted, or surfaces the fallback when a visit
  /// bounced while the step stayed unsatisfied.
  Future<void> _onResumed() async {
    final bool bounced = _bounceDetector.consumeResume();
    final int token = ++_refreshToken;
    final PermissionSnapshot? snapshot = await _readSnapshot();
    if (!mounted || token != _refreshToken) {
      return;
    }
    final OnboardingStep? step = _step;
    if (_completed || step == null || snapshot == null) {
      return;
    }
    setState(() {
      _snapshot = snapshot;
    });
    if (_isStepGranted(step, snapshot)) {
      _advance();
      return;
    }
    setState(() {
      _bounced = bounced;
    });
  }

  /// Re-reads state after a runtime dialog (no lifecycle transition).
  /// A step that became granted auto-advances.
  Future<void> _recheckAfterDialog() async {
    final int token = ++_refreshToken;
    final PermissionSnapshot? snapshot = await _readSnapshot();
    if (!mounted || token != _refreshToken) {
      return;
    }
    final OnboardingStep? step = _step;
    if (_completed || step == null || snapshot == null) {
      return;
    }
    setState(() {
      _snapshot = snapshot;
    });
    if (_isStepGranted(step, snapshot)) {
      _advance();
    }
  }

  /// Reads the snapshot through the exact Permission Center mapping.
  /// Camera is irrelevant here and reads as not-applicable. Returns null
  /// when the bridge read fails (callers keep the previous snapshot).
  Future<PermissionSnapshot?> _readSnapshot() async {
    try {
      final Map<String, Object?> native = await widget.bridge.readSnapshot();
      return PermissionSnapshot.fromSystem(
        native: native,
        camera: CapabilityState.notApplicable,
      );
    } catch (_) {
      return null;
    }
  }

  /// Primary action per step. Notifications uses the runtime dialog on
  /// API 33+ (falling back to Settings when the system will no longer
  /// prompt, or below API 33 where the dialog does not exist); every
  /// other actionable step opens its Settings target. Boot has no action.
  Future<void> _runPrimaryAction() async {
    final OnboardingStep? step = _step;
    if (step == null || _busy) {
      return;
    }
    setState(() {
      _busy = true;
      _bounced = false;
    });
    try {
      switch (step) {
        case OnboardingStep.notifications:
          await _runNotificationsAction();
        case OnboardingStep.exactAlarm:
          await _openTarget(PermissionSettingsTarget.exactAlarm);
        case OnboardingStep.fullScreen:
          await _openTarget(PermissionSettingsTarget.fullScreen);
        case OnboardingStep.boot:
          return;
        case OnboardingStep.battery:
          await _openTarget(PermissionSettingsTarget.battery);
      }
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  Future<void> _runNotificationsAction() async {
    final int sdkInt = _snapshot?.sdkInt ?? -1;
    if (sdkInt >= 0 && sdkInt < 33) {
      await _openTarget(PermissionSettingsTarget.notifications);
      return;
    }
    final NotificationPermissionOutcome outcome =
        await widget.notificationGate.requestNotifications();
    if (!mounted) {
      return;
    }
    if (outcome == NotificationPermissionOutcome.permanentlyDenied) {
      // The system will no longer prompt: continue into Settings.
      await _openTarget(PermissionSettingsTarget.notifications);
      return;
    }
    await _recheckAfterDialog();
  }

  /// Opens a Settings target, arming bounce detection on success.
  Future<void> _openTarget(PermissionSettingsTarget target) async {
    final bool launched = await widget.bridge.openSettings(target);
    if (launched && mounted) {
      _bounceDetector.arm();
    }
  }

  /// Manual advance for steps granted on arrival.
  void _advance() {
    final OnboardingStep? step = _step;
    if (step == null) {
      return;
    }
    final OnboardingStep? next = _nextStep(step);
    if (next == null) {
      _complete();
      return;
    }
    setState(() {
      _step = next;
      _bounced = false;
    });
    _skipNotApplicable();
  }

  /// Enters the completion screen, persisting the flag first. A persist
  /// failure still shows completion (the user finished); the flow simply
  /// reappears next launch.
  Future<void> _complete() async {
    try {
      await widget.onboarding.setOnboardingComplete();
    } catch (e) {
      debugPrint('OnboardingScreen: could not persist completion: $e');
    }
    if (mounted) {
      setState(() {
        _completed = true;
      });
    }
  }

  static OnboardingStep? _nextStep(OnboardingStep step) {
    final int next = step.index + 1;
    if (next >= OnboardingStep.values.length) {
      return null;
    }
    return OnboardingStep.values[next];
  }

  static bool _isStepGranted(OnboardingStep step, PermissionSnapshot s) {
    switch (step) {
      case OnboardingStep.notifications:
        return s.notifications == CapabilityState.granted;
      case OnboardingStep.exactAlarm:
        return s.exactAlarm == CapabilityState.granted;
      case OnboardingStep.fullScreen:
        return s.fullScreenIntent == CapabilityState.granted;
      case OnboardingStep.boot:
        return s.boot == CapabilityState.granted;
      case OnboardingStep.battery:
        return s.battery == CapabilityState.granted;
    }
  }

  static bool _isNotApplicable(OnboardingStep step, PermissionSnapshot? s) {
    if (s == null) {
      return false;
    }
    switch (step) {
      case OnboardingStep.exactAlarm:
        return s.exactAlarm == CapabilityState.notApplicable;
      case OnboardingStep.fullScreen:
        return s.fullScreenIntent == CapabilityState.notApplicable;
      case OnboardingStep.notifications:
      case OnboardingStep.boot:
      case OnboardingStep.battery:
        return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppStrings strings = AppStrings.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(strings.onboardingTitle)),
      body: _body(strings),
    );
  }

  Widget _body(AppStrings strings) {
    if (_completed) {
      return _completionView(strings);
    }
    final OnboardingStep? step = _step;
    if (step == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return _stepView(strings, step);
  }

  Widget _stepView(AppStrings strings, OnboardingStep step) {
    final PermissionSnapshot? snapshot = _snapshot;
    final bool granted =
        snapshot != null && _isStepGranted(step, snapshot);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Icon(_stepIcon(step), size: 64),
          const SizedBox(height: 16),
          Text(
            _stepTitle(strings, step),
            style: Theme.of(context).textTheme.headlineSmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            _stepWhy(strings, step),
            style: Theme.of(context).textTheme.bodyLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            granted ? strings.reliabilityReliable : strings.onboardingNotGranted,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          if (granted)
            FilledButton(
              key: const Key('onboarding_continue'),
              onPressed: _busy ? null : _advance,
              child: Text(strings.onboardingContinue),
            )
          else if (step != OnboardingStep.boot) ...<Widget>[
            FilledButton(
              key: const Key('onboarding_primary'),
              onPressed: _busy ? null : _runPrimaryAction,
              child: Text(_primaryLabel(strings, step)),
            ),
            if (step == OnboardingStep.battery) ...<Widget>[
              const SizedBox(height: 8),
              TextButton(
                key: const Key('onboarding_skip'),
                onPressed: _busy ? null : _complete,
                child: Text(strings.onboardingSkip),
              ),
            ],
            // Full-screen intent lives under Special App Access, a page
            // some OEM skins (Realme/ColorOS) hide or bounce away from:
            // the step always offers an explained skip so the flow can
            // never trap the user. Skipping completes onboarding; alarms
            // still ring as high-priority notifications.
            if (step == OnboardingStep.fullScreen) ...<Widget>[
              const SizedBox(height: 12),
              Text(
                strings.onboardingFullScreenSkipWhy,
                style: Theme.of(context).textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
              TextButton(
                key: const Key('onboarding_skip_fullscreen'),
                onPressed: _busy ? null : _complete,
                child: Text(strings.onboardingFullScreenSkip),
              ),
            ],
          ],
          if (_bounced && !granted) ...<Widget>[
            const SizedBox(height: 16),
            Card(
              key: const Key('onboarding_bounce_note'),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Text(_bounceNote(strings, step)),
                    const SizedBox(height: 8),
                    OutlinedButton(
                      key: const Key('onboarding_fallback'),
                      onPressed: _busy
                          ? null
                          : () => _openTarget(_fallbackTarget(step)),
                      child: Text(_fallbackLabel(strings, step)),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _completionView(AppStrings strings) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const Icon(Icons.check_circle_outline, size: 64),
          const SizedBox(height: 16),
          Text(
            strings.onboardingCompleteTitle,
            style: Theme.of(context).textTheme.headlineSmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            strings.onboardingCompleteBody,
            style: Theme.of(context).textTheme.bodyLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          FilledButton(
            key: const Key('onboarding_done'),
            onPressed: widget.onFinished,
            child: Text(strings.onboardingDone),
          ),
        ],
      ),
    );
  }

  static IconData _stepIcon(OnboardingStep step) {
    switch (step) {
      case OnboardingStep.notifications:
        return Icons.notifications;
      case OnboardingStep.exactAlarm:
        return Icons.alarm;
      case OnboardingStep.fullScreen:
        return Icons.fullscreen;
      case OnboardingStep.boot:
        return Icons.restart_alt;
      case OnboardingStep.battery:
        return Icons.battery_std;
    }
  }

  static String _stepTitle(AppStrings strings, OnboardingStep step) {
    switch (step) {
      case OnboardingStep.notifications:
        return strings.onboardingNotificationsTitle;
      case OnboardingStep.exactAlarm:
        return strings.onboardingExactTitle;
      case OnboardingStep.fullScreen:
        return strings.onboardingFullScreenTitle;
      case OnboardingStep.boot:
        return strings.onboardingBootTitle;
      case OnboardingStep.battery:
        return strings.onboardingBatteryTitle;
    }
  }

  static String _stepWhy(AppStrings strings, OnboardingStep step) {
    switch (step) {
      case OnboardingStep.notifications:
        return strings.onboardingNotificationsWhy;
      case OnboardingStep.exactAlarm:
        return strings.onboardingExactWhy;
      case OnboardingStep.fullScreen:
        return strings.onboardingFullScreenWhy;
      case OnboardingStep.boot:
        return strings.onboardingBootWhy;
      case OnboardingStep.battery:
        return strings.onboardingBatteryWhy;
    }
  }

  /// Bounce fallback per step. Full-screen intent is managed under
  /// Special App Access, so a bounced visit retries there instead of the
  /// app-info page (which lacks the toggle on some OEM skins).
  static PermissionSettingsTarget _fallbackTarget(OnboardingStep step) {
    if (step == OnboardingStep.fullScreen) {
      return PermissionSettingsTarget.specialAppAccess;
    }
    return PermissionSettingsTarget.appDetails;
  }

  static String _fallbackLabel(AppStrings strings, OnboardingStep step) {
    if (step == OnboardingStep.fullScreen) {
      return strings.onboardingSpecialAccessAction;
    }
    return strings.onboardingAppInfoAction;
  }

  static String _bounceNote(AppStrings strings, OnboardingStep step) {
    if (step == OnboardingStep.fullScreen) {
      return strings.onboardingFullScreenBounceNote;
    }
    return strings.onboardingBounceNote;
  }

  static String _primaryLabel(AppStrings strings, OnboardingStep step) {
    switch (step) {
      case OnboardingStep.notifications:
        return strings.onboardingNotificationsAction;
      case OnboardingStep.exactAlarm:
      case OnboardingStep.fullScreen:
      case OnboardingStep.battery:
        return strings.onboardingOpenSettings;
      case OnboardingStep.boot:
        return '';
    }
  }
}
