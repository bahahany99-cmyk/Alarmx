// System-capability states for the Permission Center (Phase 7).
//
// Every permission/reliability item reports one of these typed states.
// Widgets never interpret raw platform values; the snapshot maps native
// replies (and camera checks) to this enum, using [unknown] whenever the
// platform answer is missing, malformed, or unreadable.

/// Honest state of one system capability.
enum CapabilityState {
  /// The capability is available (granted / enabled / exempt).
  granted,

  /// The capability is currently off but the user can change it
  /// (denied permission, disabled switch, active battery optimization).
  denied,

  /// The capability cannot be used on this device/state and there is no
  /// user-facing switch for it (e.g. a disabled manifest component).
  unavailable,

  /// The concept does not exist on this Android version
  /// (e.g. exact-alarm access below API 31). Never actionable.
  notApplicable,

  /// The system will not grant the capability through a normal request
  /// anymore (e.g. permanently-denied camera); the user must go through
  /// system settings.
  restricted,

  /// The platform answer was missing, malformed, or the query failed.
  /// Rendered honestly as unknown — never guessed as granted or denied.
  unknown,
}
