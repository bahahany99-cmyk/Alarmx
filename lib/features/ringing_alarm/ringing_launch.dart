// Ringing launch payload (Phase 4).
//
// When a mission-gated alarm fires, the native side launches the Flutter
// UI with the frozen ring identity; [RingingAlarmBridge] delivers it as a
// [RingingLaunch]. The app boots into the mission screen for exactly this
// ring instead of Home. Malformed payloads yield `null` (normal boot)
// instead of throwing.

/// Identifies the alarm ring that opened the Flutter mission UI.
class RingingLaunch {
  const RingingLaunch({
    required this.alarmId,
    this.label,
    this.triggerAtMillis,
  });

  /// Database id of the ringing alarm.
  final int alarmId;

  /// Frozen alarm label (`null` = unlabeled).
  final String? label;

  /// Frozen schedule token (`null` for legacy rings).
  final int? triggerAtMillis;

  /// Parses a `getRingingLaunch` result, or `null` when malformed.
  static RingingLaunch? tryParse(Object? args) {
    if (args is! Map) {
      return null;
    }
    final Object? rawId = args['alarmId'];
    if (rawId is! int || rawId < 0) {
      return null;
    }
    final Object? rawLabel = args['label'];
    final Object? rawToken = args['triggerAtMillis'];
    return RingingLaunch(
      alarmId: rawId,
      label: rawLabel is String ? rawLabel : null,
      triggerAtMillis: rawToken is int ? rawToken : null,
    );
  }
}
