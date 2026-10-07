// Strict Mode domain policy (Phase 5).
//
// Centralized, pure Strict Mode rules:
//   - [canStop]: whether the normal stop path may end the ring. Strict
//     alarms hold the ring until every required mission is done; the
//     rule is enforced by the ringing session (the business layer), not
//     merely by hiding the Stop button, so screen recreation,
//     navigation, and re-entry cannot bypass it. Non-strict behavior is
//     unchanged, and a strict alarm with zero missions (or an unreadable
//     mission list) stays stoppable: strictness gates missions, it never
//     deadlocks or strands the user.
//   - [canDisableStrict]: whether the editor may switch Strict Mode off.
//     Disabling is refused inside [kStrictDisableBlackout] before the
//     alarm's next scheduled fire, so Strict Mode cannot be trivially
//     switched off in the last moments before the ring. The window is a
//     named centralized constant (a deterrent, not a lockout); enabling
//     Strict Mode is always allowed.

/// Refusal window before the next fire during which Strict Mode cannot
/// be switched off (see [StrictModePolicy.canDisableStrict]).
const Duration kStrictDisableBlackout = Duration(minutes: 30);

/// Pure Strict Mode rules; see the file docs.
class StrictModePolicy {
  const StrictModePolicy._();

  /// Whether the normal stop path may end the ring.
  ///
  /// [totalMissions] / [sessionComplete] come from the live
  /// `MissionSession` (read, never bypassed). A failed mission load
  /// stays stoppable: the ring must end even when its missions cannot.
  static bool canStop({
    required bool strictMode,
    required bool loadFailed,
    required int totalMissions,
    required bool sessionComplete,
  }) {
    if (loadFailed) {
      return true;
    }
    if (!strictMode) {
      return true;
    }
    if (totalMissions <= 0) {
      return true;
    }
    return sessionComplete;
  }

  /// Whether the editor may switch Strict Mode off for an alarm whose
  /// next scheduled fire is [nextTriggerAt] (`null` = nothing scheduled).
  ///
  /// Refuses only the true -> false flip inside the blackout window
  /// before an upcoming fire; everything else (enabling, no schedule,
  /// past schedule, distant schedule) is allowed. [now] is injected so
  /// tests pin time deterministically.
  static bool canDisableStrict({
    required bool wasStrict,
    required DateTime? nextTriggerAt,
    required DateTime now,
  }) {
    if (!wasStrict) {
      return true;
    }
    final DateTime? trigger = nextTriggerAt;
    if (trigger == null || !trigger.isAfter(now)) {
      return true;
    }
    return trigger.difference(now) > kStrictDisableBlackout;
  }
}
