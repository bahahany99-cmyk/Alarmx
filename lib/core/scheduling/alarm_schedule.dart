// Alarm schedule configuration (pure Dart, no database/Flutter/native imports).
//
// [AlarmSchedule] is the input to [NextOccurrenceCalculator]: everything the
// calculator needs to know about *when* an alarm should fire, without any
// persistence types. [AlarmSchedulingCoordinator] translates the stored
// `Alarm` row into this shape before calculating.
//
// Field contract (mirrors the schema, see `core/models/`):
//   - `hour` is 0..23 and `minute` is 0..59 (repository layer owns integrity).
//   - `onceDate` carries the calendar day for one-time alarms; only its
//     year/month/day part is used, any time component is ignored.
//   - `repeatDays` is only meaningful when `repeatType` is
//     [RepeatType.custom]; otherwise it is ignored.

import '../models/models.dart';

/// Immutable description of when an alarm should fire.
class AlarmSchedule {
  const AlarmSchedule({
    required this.repeatType,
    required this.hour,
    required this.minute,
    this.onceDate,
    this.repeatDays = RepeatDays.none,
  });

  /// How the alarm repeats (one-time, daily, selected weekdays).
  final RepeatType repeatType;

  /// Local hour of day (0..23).
  final int hour;

  /// Local minute of hour (0..59).
  final int minute;

  /// Calendar day for one-time alarms (`null` = not configured).
  final DateTime? onceDate;

  /// Selected weekdays for [RepeatType.custom] alarms.
  final RepeatDays repeatDays;
}
