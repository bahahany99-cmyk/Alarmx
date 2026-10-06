// Typed representation of the `Alarms.repeatDays` column (schema v1).
//
// The database stores a nullable 7-bit int bitmask (0..127), used only when
// `repeatType` is `custom`. Bit order is fixed: bit 0 = Sunday,
// bit 1 = Monday, ..., bit 6 = Saturday. Never reorder [Weekday]: the bit
// positions are part of the on-disk format.

/// Day of the week, with the fixed bit position used by the stored bitmask.
enum Weekday {
  sunday(0),
  monday(1),
  tuesday(2),
  wednesday(3),
  thursday(4),
  friday(5),
  saturday(6);

  const Weekday(this.bitIndex);

  /// Position of this day's bit in the mask (0..6).
  final int bitIndex;

  /// Mask with only this day's bit set.
  int get bit => 1 << bitIndex;

  /// Maps a [DateTime] to its weekday.
  ///
  /// `DateTime.weekday` counts Monday as 1 through Sunday as 7; this converts
  /// to the matching [Weekday] value.
  static Weekday fromDateTime(DateTime date) {
    return Weekday.values[date.weekday % 7];
  }
}

/// Immutable set of selected weekdays, persisted as an int bitmask.
///
/// Use [RepeatDays.mask] to write to the database and [RepeatDays.fromDays]
/// / [RepeatDays.days] to convert to and from a set of [Weekday].
class RepeatDays {
  const RepeatDays(this.mask) : assert(mask >= 0 && mask <= 127);

  /// The stored bitmask value (0..127).
  final int mask;

  /// No day selected.
  static const RepeatDays none = RepeatDays(0);

  /// Every day selected.
  static const RepeatDays all = RepeatDays(127);

  /// Monday..Friday.
  static const RepeatDays weekdays = RepeatDays(62);

  /// Sunday + Saturday.
  static const RepeatDays weekend = RepeatDays(65);

  /// Builds a selection from a set of days.
  factory RepeatDays.fromDays(Set<Weekday> days) {
    int mask = 0;
    for (final Weekday day in days) {
      mask |= day.bit;
    }
    return RepeatDays(mask);
  }

  /// Whether [day] is selected.
  bool has(Weekday day) => (mask & day.bit) != 0;

  /// Whether no day is selected.
  bool get isEmpty => mask == 0;

  /// Whether at least one day is selected.
  bool get isNotEmpty => mask != 0;

  /// The selected days as a set.
  Set<Weekday> get days {
    final Set<Weekday> result = <Weekday>{};
    for (final Weekday day in Weekday.values) {
      if (has(day)) {
        result.add(day);
      }
    }
    return result;
  }

  /// Returns a copy with [day] added.
  RepeatDays add(Weekday day) => RepeatDays(mask | day.bit);

  /// Returns a copy with [day] removed.
  RepeatDays remove(Weekday day) => RepeatDays(mask & ~day.bit);

  /// Returns a copy with [day] flipped.
  RepeatDays toggle(Weekday day) => has(day) ? remove(day) : add(day);

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is RepeatDays && other.mask == mask);

  @override
  int get hashCode => mask.hashCode;

  @override
  String toString() => 'RepeatDays($mask)';
}
