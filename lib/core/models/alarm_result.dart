// Typed representation of the `AlarmHistory.result` column (schema v1).
//
// The database stores one of the exact strings in [AlarmResult.dbValue].
// Never rename an existing `dbValue`: history rows written by older app
// versions must keep decoding.

/// How a ringing alarm episode ended.
enum AlarmResult {
  /// The alarm is (or was left) ringing; no final outcome recorded yet.
  /// This is also the default for newly inserted history rows.
  ongoing('ongoing'),

  /// The alarm was dismissed normally (all required missions solved).
  success('success'),

  /// The user stopped the alarm via the emergency-stop path.
  emergencyStop('emergency_stop'),

  /// The alarm episode failed (e.g. the process died while ringing).
  failed('failed');

  const AlarmResult(this.dbValue);

  /// Exact string stored in the database column.
  final String dbValue;

  /// Decodes a stored value.
  ///
  /// Unknown values (e.g. written by a newer app version) fall back to
  /// [AlarmResult.ongoing] instead of throwing, so old reads never crash.
  static AlarmResult fromDbValue(String value) {
    for (final AlarmResult result in AlarmResult.values) {
      if (result.dbValue == value) {
        return result;
      }
    }
    return AlarmResult.ongoing;
  }
}
