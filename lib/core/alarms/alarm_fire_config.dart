// Fire configuration carried from a persisted alarm to the native side.
//
// When [AlarmSchedulingCoordinator] schedules a real database alarm, it
// attaches an [AlarmFireConfig] built from the stored row. The config
// travels: Dart args -> AlarmManager PendingIntent extras -> AlarmReceiver
// -> AlarmForegroundService. No Flutter engine or database access is needed
// at fire time, which is what makes this safe when the app process is dead.
//
// Deliberately minimal: only fields the native service consumes.
// `volume` stays omitted on purpose: the service plays at stream volume,
// so sending it would be dead data. `soundType` is implied: a non-empty
// `soundUri` means custom, anything else the default tone.

/// How a persisted alarm should fire natively.
class AlarmFireConfig {
  const AlarmFireConfig({
    this.label,
    this.vibrationEnabled = true,
    this.soundUri,
  });

  /// Alarm label shown in the ringing notification (`null` = default text).
  final String? label;

  /// Whether the service vibrates while ringing.
  final bool vibrationEnabled;

  /// Custom sound URI string (`null`/empty = default tone). Frozen at
  /// schedule time; the service plays it first and falls back to the
  /// default tone on any failure.
  final String? soundUri;

  /// Serializes to the `scheduleExactAlarm` channel args.
  ///
  /// Keys (`label`, `vibrationEnabled`, `soundUri`) must match the parser
  /// in `AlarmSchedulerChannelHandler.kt`. Every key is always present
  /// when a config is sent, with explicit nulls for unset values.
  Map<String, Object?> toMap() {
    return <String, Object?>{
      'label': label,
      'vibrationEnabled': vibrationEnabled,
      'soundUri': soundUri,
    };
  }
}
