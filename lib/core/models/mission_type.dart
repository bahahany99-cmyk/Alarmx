// Typed representation of the `Missions.type` column (schema v1).
//
// The database stores one of the exact strings in [MissionType.dbValue].
// Mission *configuration* lives in the `configJson` column as a JSON string;
// this enum only identifies *which* mission must be solved. Never rename an
// existing `dbValue`: on-disk values must keep decoding across versions.

/// Dismiss mission attached to an alarm.
///
/// The mission logic itself is implemented in later phases; this enum only
/// provides the stable stored vocabulary.
enum MissionType {
  /// No mission: the alarm dismisses without a challenge.
  none('none'),

  /// Solve math problems to dismiss.
  math('math'),

  /// Scan the enrolled QR code to dismiss.
  qr('qr'),

  /// Scan the enrolled barcode to dismiss.
  barcode('barcode'),

  /// Take a matching photo to dismiss.
  photo('photo'),

  /// Type the shown text to dismiss.
  typing('typing'),

  /// Shake the phone to dismiss.
  shake('shake'),

  /// Match all pairs in a memory card grid to dismiss.
  memory('memory'),

  /// Tap shuffled number tiles in the prompted order to dismiss.
  sequence('sequence'),

  /// Catch bright light (or guide the glow dot) to dismiss.
  light('light');

  const MissionType(this.dbValue);

  /// Exact string stored in the database column.
  final String dbValue;

  /// Decodes a stored value.
  ///
  /// Unknown values (e.g. written by a newer app version) fall back to
  /// [MissionType.none] instead of throwing, so old reads never crash.
  static MissionType fromDbValue(String value) {
    for (final MissionType type in MissionType.values) {
      if (type.dbValue == value) {
        return type;
      }
    }
    return MissionType.none;
  }
}
