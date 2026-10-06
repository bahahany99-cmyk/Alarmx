// Fire configuration carried from a persisted alarm to the native side.
//
// When [AlarmSchedulingCoordinator] schedules a real database alarm, it
// attaches an [AlarmFireConfig] built from the stored row. The config
// travels: Dart args -> AlarmManager PendingIntent extras -> AlarmReceiver
// -> AlarmForegroundService. No Flutter engine or database access is needed
// at fire time, which is what makes this safe when the app process is dead.
//
// Deliberately minimal: only fields the current native service consumes.
// `soundType`/`soundUri`/`volume` are omitted on purpose — Phase 1.2 plays
// the default alarm ringtone at stream volume, so sending them would be
// dead data. They can extend this class (and the documented native keys)
// when per-alarm sound lands, without changing the transport.

/// How a persisted alarm should fire natively.
class AlarmFireConfig {
  const AlarmFireConfig({this.label, this.vibrationEnabled = true});

  /// Alarm label shown in the ringing notification (`null` = default text).
  final String? label;

  /// Whether the service vibrates while ringing.
  final bool vibrationEnabled;

  /// Serializes to the `scheduleExactAlarm` channel args.
  ///
  /// Keys (`label`, `vibrationEnabled`) must match the parser in
  /// `MainActivity.kt`. The label key is always present when a config is
  /// sent, with an explicit null for unlabeled alarms.
  Map<String, Object?> toMap() {
    return <String, Object?>{
      'label': label,
      'vibrationEnabled': vibrationEnabled,
    };
  }
}
