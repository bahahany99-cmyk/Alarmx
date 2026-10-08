// Pure alarm-reliability calculator (Phase 7).
//
// [computeReliability] turns a [PermissionSnapshot] plus alarm/mission
// state into a deterministic [ReliabilityReport]. It never touches
// Android APIs, never modifies alarms, and never schedules anything.
//
// Severity tiers:
//   - CRITICAL: exact alarm or notifications denied/unknown while an
//     enabled alarm depends on them.
//   - IMPORTANT: full-screen, boot, or battery findings (advisory).
//   - CONDITIONAL: camera findings, only when an enabled alarm actually
//     has a camera mission (advisory).
// `notApplicable` states and irrelevant camera findings are ready.
// Unknown states are surfaced like denials, never assumed fine.
// Without enabled alarms, critical findings demote to advisory: the
// center doubles as a setup checklist before the first alarm exists.

import 'package:alarmx/core/permissions/capability_state.dart';
import 'package:alarmx/core/permissions/permission_snapshot.dart';

/// Severity of one reliability item.
enum ReliabilityLevel {
  /// Satisfied, not applicable, or not required right now.
  ready,

  /// Outstanding recommended/conditional item, or a critical item with no
  /// enabled alarm depending on it yet.
  advisory,

  /// Must-fix for reliable alarms.
  critical,
}

/// Overall center status.
enum ReliabilityOverall {
  /// Nothing outstanding.
  reliable,

  /// Only advisories outstanding.
  mostlyReady,

  /// At least one critical finding.
  attentionRequired,
}

/// Stable identity of one reliability row.
enum ReliabilityItemId {
  notifications,
  exactAlarm,
  fullScreen,
  battery,
  boot,
  camera,
  alarmEnabled,
}

/// Calculator inputs: the system snapshot plus alarm/mission state.
class ReliabilityInput {
  const ReliabilityInput({
    required this.snapshot,
    required this.hasEnabledAlarms,
    required this.cameraRelevant,
  });

  final PermissionSnapshot snapshot;

  /// Whether at least one enabled alarm exists.
  final bool hasEnabledAlarms;

  /// Whether an enabled alarm has a camera mission (photo/QR/barcode).
  final bool cameraRelevant;
}

/// Deterministic reliability verdict: overall status plus one level per
/// item in [ReliabilityItemId] order.
class ReliabilityReport {
  const ReliabilityReport({
    required this.overall,
    required this.levels,
  });

  final ReliabilityOverall overall;

  /// Level per item; always covers every [ReliabilityItemId].
  final Map<ReliabilityItemId, ReliabilityLevel> levels;
}

/// Computes the reliability verdict for [input]. Pure and total.
ReliabilityReport computeReliability(ReliabilityInput input) {
  final PermissionSnapshot snapshot = input.snapshot;
  final bool enabled = input.hasEnabledAlarms;

  final Map<ReliabilityItemId, ReliabilityLevel> levels =
      <ReliabilityItemId, ReliabilityLevel>{
    ReliabilityItemId.notifications: _criticalTier(
      snapshot.notifications,
      enabled,
    ),
    ReliabilityItemId.exactAlarm: _criticalTier(
      snapshot.exactAlarm,
      enabled,
    ),
    ReliabilityItemId.fullScreen: _advisoryTier(snapshot.fullScreenIntent),
    ReliabilityItemId.battery: _advisoryTier(snapshot.battery),
    ReliabilityItemId.boot: _advisoryTier(snapshot.boot),
    ReliabilityItemId.camera: input.cameraRelevant
        ? _advisoryTier(snapshot.camera)
        : ReliabilityLevel.ready,
    ReliabilityItemId.alarmEnabled: ReliabilityLevel.ready,
  };

  final ReliabilityOverall overall;
  if (levels.values.any(
      (ReliabilityLevel level) => level == ReliabilityLevel.critical)) {
    overall = ReliabilityOverall.attentionRequired;
  } else if (levels.values
      .any((ReliabilityLevel level) => level == ReliabilityLevel.advisory)) {
    overall = ReliabilityOverall.mostlyReady;
  } else {
    overall = ReliabilityOverall.reliable;
  }
  return ReliabilityReport(overall: overall, levels: levels);
}

/// Critical tier (notifications, exact alarm): denied/unknown/restricted
/// is critical while an enabled alarm depends on it, advisory otherwise.
ReliabilityLevel _criticalTier(CapabilityState state, bool enabled) {
  switch (state) {
    case CapabilityState.granted:
    case CapabilityState.notApplicable:
      return ReliabilityLevel.ready;
    case CapabilityState.denied:
    case CapabilityState.unavailable:
    case CapabilityState.restricted:
    case CapabilityState.unknown:
      return enabled ? ReliabilityLevel.critical : ReliabilityLevel.advisory;
  }
}

/// Important/conditional tier: denied-like states are advisory; the row
/// text still reports the true state.
ReliabilityLevel _advisoryTier(CapabilityState state) {
  switch (state) {
    case CapabilityState.granted:
    case CapabilityState.notApplicable:
      return ReliabilityLevel.ready;
    case CapabilityState.denied:
    case CapabilityState.unavailable:
    case CapabilityState.restricted:
    case CapabilityState.unknown:
      return ReliabilityLevel.advisory;
  }
}
