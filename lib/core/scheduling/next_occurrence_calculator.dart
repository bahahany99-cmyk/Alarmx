// Pure next-occurrence calculator for alarm schedules.
//
// [NextOccurrenceCalculator] answers "given this configuration and the
// current local time, when should the alarm fire next?" It is deliberately
// boring: no Flutter, no database, no channels, no timers — just date math,
// so it is deterministic and trivially unit-testable.
//
// Rules (all in LOCAL time; recurring configuration is never converted
// to UTC):
//   - one-time: the configured day at hour:minute when strictly in the
//     future, otherwise `null` (past, exactly-now, or dateless).
//   - daily: today at hour:minute when still in the future, else tomorrow.
//   - selected weekdays: the next selected weekday at hour:minute, rolling
//     into next week; `null` when no weekday is selected.
//
// Candidates are built with `DateTime(y, m, d + offset, h, mi)` so month
// boundaries normalize and wall-clock time is preserved (better across DST
// transitions than adding 24-hour durations). Extreme DST edges (a local
// time that does not exist on one day) follow Dart's platform
// normalization and are out of scope for V1.

import '../models/models.dart';
import 'alarm_schedule.dart';

/// Calculates the next local firing time for an [AlarmSchedule].
class NextOccurrenceCalculator {
  const NextOccurrenceCalculator();

  /// Returns the next occurrence strictly after [now], or `null` when the
  /// schedule has no upcoming occurrence.
  DateTime? nextOccurrence({
    required AlarmSchedule schedule,
    required DateTime now,
  }) {
    switch (schedule.repeatType) {
      case RepeatType.once:
        return _nextOneTime(schedule, now);
      case RepeatType.daily:
        return _nextDaily(schedule, now);
      case RepeatType.custom:
        return _nextCustom(schedule, now);
    }
  }

  DateTime? _nextOneTime(AlarmSchedule schedule, DateTime now) {
    final DateTime? date = schedule.onceDate;
    if (date == null) {
      return null;
    }
    // Date part from the configured day, wall time from hour/minute; any
    // time component carried by `onceDate` itself is ignored.
    final DateTime occurrence = DateTime(
      date.year,
      date.month,
      date.day,
      schedule.hour,
      schedule.minute,
    );
    if (!occurrence.isAfter(now)) {
      return null;
    }
    return occurrence;
  }

  DateTime _nextDaily(AlarmSchedule schedule, DateTime now) {
    final DateTime today = DateTime(
      now.year,
      now.month,
      now.day,
      schedule.hour,
      schedule.minute,
    );
    if (today.isAfter(now)) {
      return today;
    }
    return DateTime(
      now.year,
      now.month,
      now.day + 1,
      schedule.hour,
      schedule.minute,
    );
  }

  DateTime? _nextCustom(AlarmSchedule schedule, DateTime now) {
    final RepeatDays days = schedule.repeatDays;
    if (days.isEmpty) {
      return null;
    }
    // Offsets 0..7 cover every weekday once, plus today's weekday again for
    // the "today selected but already passed -> same day next week" case.
    for (int offset = 0; offset <= 7; offset++) {
      final DateTime candidate = DateTime(
        now.year,
        now.month,
        now.day + offset,
        schedule.hour,
        schedule.minute,
      );
      if (offset == 0 && !candidate.isAfter(now)) {
        continue;
      }
      if (days.has(Weekday.fromDateTime(candidate))) {
        return candidate;
      }
    }
    // Unreachable while at least one day is selected.
    return null;
  }
}
