import 'package:alarmx/core/database/database.dart';
import 'package:alarmx/core/models/models.dart';

/// Pure statistics over stored history rows.
///
/// Every metric covers the current local week only: Monday 00:00 (inclusive)
/// to the next Monday 00:00 (exclusive), both constructed as local midnights
/// so daylight-saving transitions cannot shift the boundary. Rows outside the
/// window are ignored for every metric.
///
/// Result semantics mirror the stored values exactly:
/// * completed counts `success` rows only;
/// * failed counts `failed` rows only (`emergencyStop` stays distinct and is
///   counted in neither);
/// * a duration is valid when the row is not `ongoing`, `stoppedAt` is
///   present, and `stoppedAt - startedAt` is not negative. Success, failed,
///   and emergency-stop resolutions all contribute; ongoing, missing, and
///   negative spans are ignored, and negative spans are dropped (never
///   `abs()`-ed).
///
/// The hardest alarm is the identity with the highest average valid stop
/// duration; ties resolve to the first identity in input order. Labels come
/// from [labelFor], which the caller must define for every identity (using a
/// localized fallback for unknown or null ids); the calculator uses the
/// returned label verbatim and never localizes.
///
/// Averages truncate toward zero at microsecond precision. Null durations
/// mean "unavailable" — callers must render a localized unavailable state and
/// never manufacture `0:00`.
AlarmStatistics computeStatistics({
  required List<AlarmHistoryData> rows,
  required DateTime now,
  required String? Function(int? alarmId) labelFor,
}) {
  final DateTime weekStart = startOfWeekLocal(now);
  final DateTime weekEnd = DateTime(
    weekStart.year,
    weekStart.month,
    weekStart.day + DateTime.daysPerWeek,
  );

  int completed = 0;
  int failed = 0;
  final List<Duration> valid = <Duration>[];
  final Map<int?, List<Duration>> byAlarm = <int?, List<Duration>>{};
  final List<int?> firstSeen = <int?>[];
  for (final AlarmHistoryData row in rows) {
    if (row.startedAt.isBefore(weekStart) ||
        !row.startedAt.isBefore(weekEnd)) {
      continue;
    }
    final AlarmResult result = AlarmResult.fromDbValue(row.result);
    if (result == AlarmResult.success) {
      completed++;
    }
    if (result == AlarmResult.failed) {
      failed++;
    }
    final DateTime? stoppedAt = row.stoppedAt;
    if (result == AlarmResult.ongoing || stoppedAt == null) {
      continue;
    }
    final Duration span = stoppedAt.difference(row.startedAt);
    if (span.isNegative) {
      continue;
    }
    valid.add(span);
    if (!byAlarm.containsKey(row.alarmId)) {
      byAlarm[row.alarmId] = <Duration>[];
      firstSeen.add(row.alarmId);
    }
    byAlarm[row.alarmId]!.add(span);
  }

  Duration? average;
  Duration? fastest;
  if (valid.isNotEmpty) {
    int totalMicros = 0;
    Duration min = valid.first;
    for (final Duration span in valid) {
      totalMicros += span.inMicroseconds;
      if (span < min) {
        min = span;
      }
    }
    average = Duration(microseconds: totalMicros ~/ valid.length);
    fastest = min;
  }

  String? hardestLabel;
  Duration? hardestAverage;
  for (final int? alarmId in firstSeen) {
    final List<Duration> spans = byAlarm[alarmId]!;
    int totalMicros = 0;
    for (final Duration span in spans) {
      totalMicros += span.inMicroseconds;
    }
    final Duration mean =
        Duration(microseconds: totalMicros ~/ spans.length);
    if (hardestAverage == null || mean > hardestAverage) {
      hardestAverage = mean;
      hardestLabel = labelFor(alarmId);
    }
  }

  return AlarmStatistics(
    completedThisWeek: completed,
    failedThisWeek: failed,
    averageStop: average,
    fastestStop: fastest,
    hardestAlarmLabel: hardestLabel,
    hardestAverage: hardestAverage,
  );
}

/// Monday 00:00 local of the week containing [now].
///
/// Built by date arithmetic (never by subtracting 24-hour blocks) so the
/// result is always a true local midnight, even across DST transitions.
DateTime startOfWeekLocal(DateTime now) {
  final DateTime today = DateTime(now.year, now.month, now.day);
  return DateTime(
    today.year,
    today.month,
    today.day - (now.weekday - DateTime.monday),
  );
}

/// Week summary over real history rows. See [computeStatistics].
class AlarmStatistics {
  const AlarmStatistics({
    required this.completedThisWeek,
    required this.failedThisWeek,
    required this.averageStop,
    required this.fastestStop,
    required this.hardestAlarmLabel,
    required this.hardestAverage,
  });

  /// In-window rows with result `success`.
  final int completedThisWeek;

  /// In-window rows with result `failed`.
  final int failedThisWeek;

  /// Mean valid stop duration, or null when the week has none.
  final Duration? averageStop;

  /// Shortest valid stop duration, or null when the week has none.
  final Duration? fastestStop;

  /// Label of the hardest alarm, or null when the week has no valid stop.
  final String? hardestAlarmLabel;

  /// The hardest alarm's average valid stop duration (null together with
  /// [hardestAlarmLabel]).
  final Duration? hardestAverage;
}
