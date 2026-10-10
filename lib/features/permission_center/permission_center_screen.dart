// Permission Center screen (Phase 7): the one place showing whether the
// Android conditions for reliable alarms hold, and where Android can take
// the user to fix them.
//
// The screen reads real system state through [readReliability] when it
// opens, when it resumes (returning from Settings), and after every
// settings action. No polling, no timers. Every row reports its true
// capability state as text plus an icon (never color alone); rows with a
// real system page offer one user-initiated action, and rows without one
// (boot info, camera when merely requestable, N/A capabilities) explain
// instead of faking a button. Settings launches are bounce-guarded:
// when the app resumes within 1500ms of a launch, the target page
// closed (near-)instantly (OEM skins that resolve-but-kill deep
// links), so a message offers the app-info page instead of leaving
// the user on a silently failed redirect.

import 'package:alarmx/core/l10n/app_strings.dart';
import 'package:alarmx/core/permissions/capability_state.dart';
import 'package:alarmx/core/permissions/permission_bridge.dart';
import 'package:alarmx/core/permissions/settings_bounce_detector.dart';
import 'package:alarmx/core/repositories/alarm_repository.dart';
import 'package:alarmx/features/missions/mission_service.dart';
import 'package:alarmx/features/missions/permissions/camera_permission.dart';
import 'package:alarmx/features/permission_center/reliability_calculator.dart';
import 'package:alarmx/features/permission_center/reliability_reader.dart';
import 'package:flutter/material.dart';

/// Central alarm-reliability surface; see the file docs.
class PermissionCenterScreen extends StatefulWidget {
  const PermissionCenterScreen({
    super.key,
    required this.bridge,
    required this.cameraGate,
    required this.alarms,
    required this.missions,
    this.clock,
  });

  /// Clock for settings-bounce timing; defaults to [DateTime.now].
  /// Tests pass a scripted clock to cross the bounce threshold on demand.
  final DateTime Function()? clock;

  final PermissionSystemBridge bridge;
  final CameraPermissionGate cameraGate;
  final AlarmRepository alarms;
  final MissionService missions;

  @override
  State<PermissionCenterScreen> createState() => _PermissionCenterScreenState();
}

class _PermissionCenterScreenState extends State<PermissionCenterScreen>
    with WidgetsBindingObserver {
  bool _loading = true;
  bool _loadFailed = false;
  ReliabilityData? _data;
  int _reloadToken = 0;

  /// Shared bounce detector: armed on every launched settings action,
  /// judged on the next resume (see [_maybeReportBounce]). Threshold and
  /// verdict semantics are the detector's; this screen only renders the
  /// verdict. Behavior is identical to the previously inline logic.
  late final SettingsBounceDetector _bounceDetector =
      SettingsBounceDetector(clock: widget.clock);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _reload();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _maybeReportBounce();
      _reload();
    }
  }

  Future<void> _reload() async {
    final int token = ++_reloadToken;
    setState(() {
      _loading = true;
      _loadFailed = false;
    });
    try {
      final ReliabilityData data = await readReliability(
        bridge: widget.bridge,
        cameraGate: widget.cameraGate,
        alarms: widget.alarms,
        missions: widget.missions,
      );
      if (!mounted || token != _reloadToken) {
        return;
      }
      setState(() {
        _data = data;
        _loading = false;
      });
    } catch (_) {
      if (!mounted || token != _reloadToken) {
        return;
      }
      setState(() {
        _loadFailed = true;
        _loading = false;
      });
    }
  }

  Future<void> _openSettings(PermissionSettingsTarget target) async {
    final bool launched = await widget.bridge.openSettings(target);
    if (!mounted) {
      return;
    }
    if (!launched) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppStrings.of(context).permissionCenterActionFailed),
        ),
      );
    } else {
      // Arm bounce detection: the resume observer judges whether the
      // target page actually hosted the user (see [_maybeReportBounce]).
      // Generic across targets — any OEM-broken deep link trips it.
      _bounceDetector.arm();
    }
    // Explicit refresh after returning; the resume observer refreshes too.
    await _reload();
  }

  /// Reports a settings "bounce": the app resumed within [_bounceThreshold]
  /// of a launched settings action, meaning the target page closed
  /// (near-)instantly instead of hosting the user. Offers the app-info
  /// page (confirmed working where deep links bounce) via an explicit
  /// action — never silently retries the broken intent. A slower return
  /// is a genuine visit and does nothing extra. Consumes the armed stamp
  /// exactly once, so each launch gets one verdict and plain resumes
  /// (no launch) stay silent.
  void _maybeReportBounce() {
    if (!_bounceDetector.consumeResume() || !mounted) {
      return;
    }
    final AppStrings strings = AppStrings.of(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(strings.permissionCenterBounceMessage),
        action: SnackBarAction(
          label: strings.permissionCenterBounceFallback,
          onPressed: () {
            _openSettings(PermissionSettingsTarget.appDetails);
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppStrings strings = AppStrings.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(strings.permissionCenterTitle),
        actions: <Widget>[
          IconButton(
            key: const Key('permission_center_refresh'),
            icon: const Icon(Icons.refresh),
            tooltip: strings.permissionCenterRefresh,
            onPressed: _reload,
          ),
        ],
      ),
      body: Builder(
        builder: (BuildContext context) {
          if (_loadFailed) {
            return _ErrorState(onRetry: _reload);
          }
          if (_loading || _data == null) {
            return const Center(child: CircularProgressIndicator());
          }
          return _CenterLoaded(
            data: _data!,
            onAction: _openSettings,
          );
        },
      ),
    );
  }
}

class _CenterLoaded extends StatelessWidget {
  const _CenterLoaded({required this.data, required this.onAction});

  final ReliabilityData data;
  final Future<void> Function(PermissionSettingsTarget target) onAction;

  @override
  Widget build(BuildContext context) {
    // Fixed seven rows: a Column builds every row eagerly (a lazy list
    // would only inflate visible rows, hiding the rest from semantics
    // and tests until scrolled).
    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: <Widget>[
          _OverallCard(overall: data.report.overall),
          _CenterItemCard(
            item: _NotificationsItem(data),
            onAction: onAction,
          ),
          _CenterItemCard(
            item: _ExactAlarmItem(data),
            onAction: onAction,
          ),
          _CenterItemCard(
            item: _FullScreenItem(data),
            onAction: onAction,
          ),
          _CenterItemCard(
            item: _BatteryItem(data),
            onAction: onAction,
          ),
          _CenterItemCard(
            item: _BootItem(data),
            onAction: onAction,
          ),
          _CenterItemCard(
            item: _CameraItem(data),
            onAction: onAction,
          ),
          _CenterItemCard(
            item: _AlarmsItem(data),
            onAction: onAction,
          ),
        ],
      ),
    );
  }
}

class _OverallCard extends StatelessWidget {
  const _OverallCard({required this.overall});

  final ReliabilityOverall overall;

  @override
  Widget build(BuildContext context) {
    final AppStrings strings = AppStrings.of(context);
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;
    final String title;
    final String explain;
    final IconData icon;
    final Color color;
    switch (overall) {
      case ReliabilityOverall.reliable:
        title = strings.reliabilityReliable;
        explain = strings.reliabilityExplainReliable;
        icon = Icons.verified;
        color = colors.primary;
        break;
      case ReliabilityOverall.mostlyReady:
        title = strings.reliabilityMostly;
        explain = strings.reliabilityExplainMostly;
        icon = Icons.warning_amber;
        color = colors.tertiary;
        break;
      case ReliabilityOverall.attentionRequired:
        title = strings.reliabilityAttention;
        explain = strings.reliabilityExplainAttention;
        icon = Icons.error;
        color = colors.error;
        break;
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Icon(icon, color: color, semanticLabel: title),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(explain, style: theme.textTheme.bodyMedium),
                  const SizedBox(height: 8),
                  Text(
                    strings.permissionCenterSubtitle,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One rendered center row: icon, true capability state, severity level,
/// optional settings target, and the row-specific display inputs.
class _CenterItem {
  const _CenterItem({
    required this.id,
    required this.icon,
    required this.state,
    required this.level,
    required this.target,
    this.enabledCount = 0,
    this.cameraRelevant = false,
  });

  final String id;
  final IconData icon;
  final CapabilityState state;
  final ReliabilityLevel level;
  final PermissionSettingsTarget? target;
  final int enabledCount;
  final bool cameraRelevant;
}

_CenterItem _NotificationsItem(ReliabilityData data) {
  return _CenterItem(
    id: 'notifications',
    icon: Icons.notifications,
    state: data.snapshot.notifications,
    level: data.report.levels[ReliabilityItemId.notifications]!,
    target: PermissionSettingsTarget.notifications,
  );
}

_CenterItem _ExactAlarmItem(ReliabilityData data) {
  final CapabilityState state = data.snapshot.exactAlarm;
  return _CenterItem(
    id: 'exactAlarm',
    icon: Icons.alarm,
    state: state,
    level: data.report.levels[ReliabilityItemId.exactAlarm]!,
    target: state == CapabilityState.notApplicable
        ? null
        : PermissionSettingsTarget.exactAlarm,
  );
}

_CenterItem _FullScreenItem(ReliabilityData data) {
  final CapabilityState state = data.snapshot.fullScreenIntent;
  return _CenterItem(
    id: 'fullScreen',
    icon: Icons.fullscreen,
    state: state,
    level: data.report.levels[ReliabilityItemId.fullScreen]!,
    target: state == CapabilityState.notApplicable
        ? null
        : PermissionSettingsTarget.fullScreen,
  );
}

_CenterItem _BatteryItem(ReliabilityData data) {
  return _CenterItem(
    id: 'battery',
    icon: Icons.battery_std,
    state: data.snapshot.battery,
    level: data.report.levels[ReliabilityItemId.battery]!,
    target: PermissionSettingsTarget.battery,
  );
}

_CenterItem _BootItem(ReliabilityData data) {
  // Manifest capability with no user toggle: informational, never a fake
  // button.
  return _CenterItem(
    id: 'boot',
    icon: Icons.restart_alt,
    state: data.snapshot.boot,
    level: data.report.levels[ReliabilityItemId.boot]!,
    target: null,
  );
}

_CenterItem _CameraItem(ReliabilityData data) {
  final CapabilityState state = data.snapshot.camera;
  return _CenterItem(
    id: 'camera',
    icon: Icons.camera_alt,
    state: state,
    level: data.report.levels[ReliabilityItemId.camera]!,
    cameraRelevant: data.cameraRelevant,
    // App settings only when restricted: a merely requestable denial is
    // resolved by running a camera mission, never by this screen.
    target: data.cameraRelevant && state == CapabilityState.restricted
        ? PermissionSettingsTarget.appDetails
        : null,
  );
}

_CenterItem _AlarmsItem(ReliabilityData data) {
  return _CenterItem(
    id: 'alarms',
    icon: Icons.alarm_on,
    state: CapabilityState.granted,
    level: data.report.levels[ReliabilityItemId.alarmEnabled]!,
    target: null,
    enabledCount: data.enabledCount,
  );
}

class _CenterItemCard extends StatelessWidget {
  const _CenterItemCard({required this.item, required this.onAction});

  final _CenterItem item;
  final Future<void> Function(PermissionSettingsTarget target) onAction;

  @override
  Widget build(BuildContext context) {
    final AppStrings strings = AppStrings.of(context);
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;
    final Color levelColor;
    switch (item.level) {
      case ReliabilityLevel.ready:
        levelColor = colors.primary;
        break;
      case ReliabilityLevel.advisory:
        levelColor = colors.tertiary;
        break;
      case ReliabilityLevel.critical:
        levelColor = colors.error;
        break;
    }
    final PermissionSettingsTarget? target = item.target;
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            ListTile(
              leading: Icon(
                item.icon,
                color: levelColor,
                semanticLabel: _statusText(strings),
              ),
              title: Text(_title(strings)),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const SizedBox(height: 4),
                  Row(
                    children: <Widget>[
                      Flexible(
                        child: Text(
                          _statusText(strings),
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: levelColor,
                          ),
                        ),
                      ),
                      if (_tag(strings) != null) ...<Widget>[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: colors.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            _tag(strings)!,
                            style: theme.textTheme.labelSmall,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _explain(strings),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            if (target != null)
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: Padding(
                  padding: const EdgeInsetsDirectional.only(
                    end: 8,
                    bottom: 8,
                  ),
                  child: FilledButton.tonal(
                    key: Key('permission_action_${item.id}'),
                    onPressed: () {
                      onAction(target);
                    },
                    child: Text(strings.permissionCenterFix),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _title(AppStrings strings) {
    switch (item.id) {
      case 'notifications':
        return strings.permNotificationsTitle;
      case 'exactAlarm':
        return strings.permExactAlarmTitle;
      case 'fullScreen':
        return strings.permFullScreenTitle;
      case 'battery':
        return strings.permBatteryTitle;
      case 'boot':
        return strings.permBootTitle;
      case 'camera':
        return strings.permCameraTitle;
      case 'alarms':
        return strings.permAlarmsTitle;
    }
    return item.id;
  }

  String _explain(AppStrings strings) {
    switch (item.id) {
      case 'notifications':
        return strings.permNotificationsExplain;
      case 'exactAlarm':
        return strings.permExactAlarmExplain;
      case 'fullScreen':
        return strings.permFullScreenExplain;
      case 'battery':
        return strings.permBatteryExplain;
      case 'boot':
        return strings.permBootExplain;
      case 'camera':
        return strings.permCameraExplain;
      case 'alarms':
        return strings.permAlarmsExplain;
    }
    return '';
  }

  String? _tag(AppStrings strings) {
    switch (item.id) {
      case 'notifications':
      case 'exactAlarm':
      case 'fullScreen':
      case 'boot':
        return strings.permTagRequired;
      case 'battery':
        return strings.permTagRecommended;
      case 'camera':
        return strings.permTagConditional;
      case 'alarms':
        return null;
    }
    return null;
  }

  String _statusText(AppStrings strings) {
    // The alarms row reports the enabled count, not a capability state.
    if (item.id == 'alarms') {
      return item.enabledCount == 0 ? strings.permAlarmsNone : '${item.enabledCount}';
    }
    // An unneeded camera reads as not required even when denied: nothing
    // is wrong, and the center must not nag for a JIT permission.
    if (item.id == 'camera' &&
        !item.cameraRelevant &&
        item.state != CapabilityState.granted) {
      return strings.permStateNotRequired;
    }
    switch (item.state) {
      case CapabilityState.granted:
        return strings.permStateReady;
      case CapabilityState.denied:
        if (item.id == 'battery') {
          return strings.permStateNotExempt;
        }
        return strings.permStateDenied;
      case CapabilityState.unavailable:
        return strings.permStateUnavailable;
      case CapabilityState.notApplicable:
        return strings.permStateNotApplicable;
      case CapabilityState.restricted:
        return strings.permStateRestricted;
      case CapabilityState.unknown:
        return strings.permStateUnknown;
    }
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.onRetry});

  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    final AppStrings strings = AppStrings.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              strings.permissionCenterLoadFailed,
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            FilledButton(
              key: const Key('permission_center_retry'),
              onPressed: onRetry,
              child: Text(strings.permissionCenterRetry),
            ),
          ],
        ),
      ),
    );
  }
}
