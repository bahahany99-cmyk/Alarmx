// Presentation-only formatting for stored alarm values (Phase 3).
//
// Everything here FORMATS values that already exist in the database row
// (hour/minute, repeat fields, `nextTriggerAt`). Nothing here computes,
// predicts, or re-derives trigger times: the next occurrence comes only
// from the coordinator/calculator pipeline, and the UI renders the stored
// `nextTriggerAt` verbatim. Date/time rendering goes through
// `MaterialLocalizations` so digits, order, and calendar follow the active
// locale (Arabic with the SDK `flutter_localizations` delegates).
//
// All functions are defensive against legacy/garbage rows (out-of-range
// hour/minute, unknown repeat strings, oversized day masks) so the Home
// list never crashes on stored data.

import 'package:alarmx/core/database/database.dart';
import 'package:alarmx/core/l10n/app_strings.dart';
import 'package:alarmx/core/models/models.dart';
import 'package:flutter/material.dart';

/// Short localized name of [day] (chip label / repeat description part).
String weekdayName(AppStrings strings, Weekday day) {
  switch (day) {
    case Weekday.sunday:
      return strings.daySun;
    case Weekday.monday:
      return strings.dayMon;
    case Weekday.tuesday:
      return strings.dayTue;
    case Weekday.wednesday:
      return strings.dayWed;
    case Weekday.thursday:
      return strings.dayThu;
    case Weekday.friday:
      return strings.dayFri;
    case Weekday.saturday:
      return strings.daySat;
  }
}

/// Alarm wall-clock time rendered in the ambient locale, e.g. "7:00 AM".
String formatAlarmTime(BuildContext context, int hour, int minute) {
  final TimeOfDay time = TimeOfDay(
    hour: hour.clamp(0, 23),
    minute: minute.clamp(0, 59),
  );
  return MaterialLocalizations.of(context).formatTimeOfDay(
    time,
    alwaysUse24HourFormat: false,
  );
}

/// One-line repeat description for a stored alarm.
///
///  - once: the stored date ("Thu, Oct 8" style), or "Once" when dateless.
///  - daily: "Daily" / "يومي".
///  - custom: the selected day names joined with the locale separator,
///    or the "no days" hint for an empty selection (unreachable through
///    the Phase 3 editor, which validates, but possible in legacy rows).
String describeRepeat(BuildContext context, Alarm alarm) {
  final AppStrings strings = AppStrings.of(context);
  final MaterialLocalizations material = MaterialLocalizations.of(context);
  switch (RepeatType.fromDbValue(alarm.repeatType)) {
    case RepeatType.once:
      final DateTime? date = alarm.onceDate;
      if (date == null) {
        return strings.repeatOnce;
      }
      return material.formatMediumDate(date);
    case RepeatType.daily:
      return strings.repeatDaily;
    case RepeatType.custom:
      final RepeatDays days = RepeatDays((alarm.repeatDays ?? 0) & 127);
      if (days.isEmpty) {
        return strings.repeatCustom;
      }
      final List<String> names = <String>[
        for (final Weekday day in Weekday.values)
          if (days.has(day)) weekdayName(strings, day),
      ];
      return names.join(strings.listSeparator);
  }
}

/// Next-ring line for a stored alarm: "Next: <date> <time>" when the alarm
/// is enabled and the coordinator persisted a trigger, else "Not scheduled".
///
/// Renders the stored `nextTriggerAt` verbatim; never computes anything.
String describeNextTrigger(BuildContext context, Alarm alarm) {
  final AppStrings strings = AppStrings.of(context);
  final DateTime? trigger = alarm.nextTriggerAt;
  if (!alarm.enabled || trigger == null) {
    return strings.notScheduled;
  }
  final MaterialLocalizations material = MaterialLocalizations.of(context);
  final String date = material.formatMediumDate(trigger);
  final String time = material.formatTimeOfDay(
    TimeOfDay(hour: trigger.hour, minute: trigger.minute),
    alwaysUse24HourFormat: false,
  );
  return '${strings.nextLabel}: $date $time';
}
