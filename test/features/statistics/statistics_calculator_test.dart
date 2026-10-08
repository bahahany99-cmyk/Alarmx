import 'package:alarmx/core/database/database.dart';
import 'package:alarmx/core/models/models.dart';
import 'package:alarmx/features/statistics/statistics_calculator.dart';
import 'package:flutter_test/flutter_test.dart';

// Pure calculator tests (A-M): no database, no widgets. The fixture week is
// Mon 2026-10-05 00:00 (inclusive) to Mon 2026-10-12 00:00 (exclusive).

void main() {
  final DateTime now = DateTime(2026, 10, 7, 12); // Wednesday.

  AlarmHistoryData row({
    int? alarmId = 1,
    required DateTime startedAt,
    DateTime? stoppedAt,
    AlarmResult result = AlarmResult.success,
  }) {
    return AlarmHistoryData(
      id: 0,
      alarmId: alarmId,
      startedAt: startedAt,
      stoppedAt: stoppedAt,
      result: result.dbValue,
      attempts: 0,
      snoozeCount: 0,
    );
  }

  DateTime at(int day, int hour, [int minute = 0, int second = 0]) =>
      DateTime(2026, 10, day, hour, minute, second);

  String? labels(int? alarmId) =>
      alarmId == null ? 'Deleted alarm' : 'Alarm $alarmId';

  AlarmStatistics compute(List<AlarmHistoryData> rows) => computeStatistics(
        rows: rows,
        now: now,
        labelFor: labels,
      );

  test('A: empty input yields zeros and unavailable durations', () {
    final AlarmStatistics stats = compute(<AlarmHistoryData>[]);
    expect(stats.completedThisWeek, 0);
    expect(stats.failedThisWeek, 0);
    expect(stats.averageStop, isNull);
    expect(stats.fastestStop, isNull);
    expect(stats.hardestAlarmLabel, isNull);
    expect(stats.hardestAverage, isNull);
  });

  test('B: window is Monday 00:00 inclusive to next Monday exclusive', () {
    final AlarmStatistics stats = compute(<AlarmHistoryData>[
      row(startedAt: at(4, 23, 59, 59), stoppedAt: at(5, 0, 59, 59)), // out
      row(startedAt: at(5), stoppedAt: at(5, 0, 1)), // in, 60s
      row(startedAt: at(11, 23, 59, 59), stoppedAt: at(12, 0, 1, 59)), // in, 120s
      row(startedAt: at(12), stoppedAt: at(12, 1)), // out
    ]);
    expect(stats.completedThisWeek, 2);
    expect(stats.averageStop, const Duration(seconds: 90));
    expect(stats.fastestStop, const Duration(seconds: 60));
  });

  test('C: completed counts success only', () {
    final AlarmStatistics stats = compute(<AlarmHistoryData>[
      row(startedAt: at(6, 6), stoppedAt: at(6, 6, 1)),
      row(
        startedAt: at(6, 7),
        stoppedAt: at(6, 7, 1),
        result: AlarmResult.failed,
      ),
      row(
        startedAt: at(6, 8),
        stoppedAt: at(6, 8, 1),
        result: AlarmResult.emergencyStop,
      ),
      row(startedAt: at(6, 9), result: AlarmResult.ongoing),
    ]);
    expect(stats.completedThisWeek, 1);
  });

  test('D: failed counts failed only', () {
    final AlarmStatistics stats = compute(<AlarmHistoryData>[
      row(startedAt: at(6, 6), stoppedAt: at(6, 6, 1)),
      row(
        startedAt: at(6, 7),
        stoppedAt: at(6, 7, 1),
        result: AlarmResult.failed,
      ),
      row(
        startedAt: at(6, 8),
        stoppedAt: at(6, 8, 1),
        result: AlarmResult.emergencyStop,
      ),
      row(startedAt: at(6, 9), result: AlarmResult.ongoing),
    ]);
    expect(stats.failedThisWeek, 1);
  });

  test('E: average spans valid durations', () {
    final AlarmStatistics stats = compute(<AlarmHistoryData>[
      row(startedAt: at(6, 6), stoppedAt: at(6, 6, 1)),
      row(startedAt: at(6, 7), stoppedAt: at(6, 7, 2)),
      row(startedAt: at(6, 8), stoppedAt: at(6, 8, 3)),
    ]);
    expect(stats.averageStop, const Duration(seconds: 120));
  });

  test('F: fastest is the shortest valid duration', () {
    final AlarmStatistics stats = compute(<AlarmHistoryData>[
      row(startedAt: at(6, 6), stoppedAt: at(6, 6, 3)),
      row(startedAt: at(6, 7), stoppedAt: at(6, 7, 1)),
      row(startedAt: at(6, 8), stoppedAt: at(6, 8, 2)),
    ]);
    expect(stats.fastestStop, const Duration(seconds: 60));
  });

  test('G: failed and emergency resolutions contribute durations', () {
    final AlarmStatistics stats = compute(<AlarmHistoryData>[
      row(startedAt: at(6, 6), stoppedAt: at(6, 6, 1, 40)),
      row(
        startedAt: at(6, 7),
        stoppedAt: at(6, 7, 3, 20),
        result: AlarmResult.failed,
      ),
      row(
        startedAt: at(6, 8),
        stoppedAt: at(6, 8, 5),
        result: AlarmResult.emergencyStop,
      ),
    ]);
    expect(stats.averageStop, const Duration(seconds: 200));
    expect(stats.fastestStop, const Duration(seconds: 100));
  });

  test('H: ongoing rows never contribute durations', () {
    final AlarmStatistics stats = compute(<AlarmHistoryData>[
      row(
        startedAt: at(6, 6),
        stoppedAt: at(6, 6, 0, 50),
        result: AlarmResult.ongoing,
      ),
      row(startedAt: at(6, 7), stoppedAt: at(6, 7, 1, 40)),
    ]);
    expect(stats.completedThisWeek, 1);
    expect(stats.averageStop, const Duration(seconds: 100));
    expect(stats.fastestStop, const Duration(seconds: 100));
  });

  test('I: missing stops count for results but not durations', () {
    final AlarmStatistics stats = compute(<AlarmHistoryData>[
      row(startedAt: at(6, 6)),
      row(startedAt: at(6, 7), stoppedAt: at(6, 7, 1, 40)),
    ]);
    expect(stats.completedThisWeek, 2);
    expect(stats.averageStop, const Duration(seconds: 100));
    expect(stats.fastestStop, const Duration(seconds: 100));
  });

  test('J: negative spans are dropped, never abs()', () {
    final AlarmStatistics stats = compute(<AlarmHistoryData>[
      row(startedAt: at(6, 6, 1), stoppedAt: at(6, 6)),
      row(startedAt: at(6, 7), stoppedAt: at(6, 7, 1, 40)),
    ]);
    expect(stats.averageStop, const Duration(seconds: 100));
    expect(stats.fastestStop, const Duration(seconds: 100));
  });

  test('K: hardest alarm has the highest average duration', () {
    final AlarmStatistics stats = compute(<AlarmHistoryData>[
      row(alarmId: 1, startedAt: at(6, 6), stoppedAt: at(6, 6, 1)),
      row(alarmId: 1, startedAt: at(6, 7), stoppedAt: at(6, 7, 2)),
      row(alarmId: 2, startedAt: at(6, 8), stoppedAt: at(6, 8, 5)),
    ]);
    expect(stats.averageStop, const Duration(seconds: 160));
    expect(stats.hardestAlarmLabel, 'Alarm 2');
    expect(stats.hardestAverage, const Duration(seconds: 300));
  });

  test('L: hardest ties resolve to first input order; labels verbatim', () {
    final AlarmStatistics stats = compute(<AlarmHistoryData>[
      row(alarmId: 5, startedAt: at(6, 6), stoppedAt: at(6, 6, 1, 40)),
      row(alarmId: 6, startedAt: at(6, 7), stoppedAt: at(6, 7, 1, 40)),
    ]);
    expect(stats.hardestAlarmLabel, 'Alarm 5');

    final AlarmStatistics missing = compute(<AlarmHistoryData>[
      row(alarmId: null, startedAt: at(6, 6), stoppedAt: at(6, 6, 0, 50)),
    ]);
    expect(missing.hardestAlarmLabel, 'Deleted alarm');
    expect(missing.hardestAverage, const Duration(seconds: 50));
  });

  test('M: week starts Monday 00:00 local', () {
    expect(startOfWeekLocal(DateTime(2026, 10, 5, 15, 30)),
        DateTime(2026, 10, 5));
    expect(startOfWeekLocal(DateTime(2026, 10, 11, 23, 59)),
        DateTime(2026, 10, 5));
    expect(startOfWeekLocal(now), DateTime(2026, 10, 5));
    expect(startOfWeekLocal(DateTime(2026, 10, 12)), DateTime(2026, 10, 12));
  });
}
