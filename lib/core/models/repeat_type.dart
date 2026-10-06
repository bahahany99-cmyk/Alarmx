// Typed representation of the `Alarms.repeatType` column (schema v1).
//
// The database stores one of the exact strings in [RepeatType.dbValue].
// Business logic must use this enum instead of raw strings; the repository
// and scheduler layers translate at the boundary. Never rename an existing
// `dbValue`: on-disk values written by older app versions must keep decoding.

/// How an alarm repeats.
enum RepeatType {
  /// Fires once, on `onceDate` at the alarm's hour/minute.
  once('once'),

  /// Fires every day at the alarm's hour/minute.
  daily('daily'),

  /// Fires on the weekdays selected in the `repeatDays` bitmask.
  custom('custom');

  const RepeatType(this.dbValue);

  /// Exact string stored in the database column.
  final String dbValue;

  /// Decodes a stored value.
  ///
  /// Unknown values (e.g. written by a newer app version) fall back to
  /// [RepeatType.once] instead of throwing, so old reads never crash.
  static RepeatType fromDbValue(String value) {
    for (final RepeatType type in RepeatType.values) {
      if (type.dbValue == value) {
        return type;
      }
    }
    return RepeatType.once;
  }
}
