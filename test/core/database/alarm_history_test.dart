import 'package:alarmx/core/database/database.dart';
import 'package:alarmx/core/models/models.dart';
import 'package:alarmx/core/repositories/alarm_history_repository.dart';
import 'package:alarmx/core/repositories/alarm_repository.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

// Phase 6 history query guarantees: newest-first ordering (one-shot and
// reactive), history surviving alarm deletion, and round-trip
// preservation of results, timestamps, attempts, and snooze counts.
// Every test runs against a fresh in-memory database.

void main() {
  late AppDatabase db;
  late AlarmRepository alarms;
  late AlarmHistoryRepository history;

  setUp(() {
    db = AppDatabase.connect(NativeDatabase.memory());
    alarms = DriftAlarmRepository(db.alarmDao);
    history = DriftAlarmHistoryRepository(db.alarmHistoryDao);
  });

  tearDown(() async {
    await db.close();
  });

  // Whole-second timestamps: drift stores DateTimes at second precision.
  DateTime at(int day, int hour, int minute) =>
      DateTime(2026, 10, day, hour, minute);

  Future<int> insertRow({
    int? alarmId,
    required DateTime startedAt,
    DateTime? stoppedAt,
    AlarmResult result = AlarmResult.ongoing,
    int attempts = 0,
    int snoozeCount = 0,
  }) {
    return history.insertHistory(
      AlarmHistoryCompanion.insert(
        alarmId: Value<int?>(alarmId),
        startedAt: startedAt,
        stoppedAt: Value<DateTime?>(stoppedAt),
        result: Value<String>(result.dbValue),
        attempts: Value<int>(attempts),
        snoozeCount: Value<int>(snoozeCount),
      ),
    );
  }

  test('getAllHistory returns rows newest first', () async {
    await insertRow(startedAt: at(1, 6, 0));
    await insertRow(startedAt: at(3, 6, 0));
    await insertRow(startedAt: at(2, 6, 0));

    final List<AlarmHistoryData> rows = await history.getAllHistory();
    expect(
      rows.map((AlarmHistoryData row) => row.startedAt),
      orderedEquals(<DateTime>[at(3, 6, 0), at(2, 6, 0), at(1, 6, 0)]),
    );
  });

  test('watchAllHistory emits newest first and reflects inserts', () async {
    await insertRow(startedAt: at(1, 6, 0));
    List<AlarmHistoryData> rows = await history.watchAllHistory().first;
    expect(rows.length, 1);

    await insertRow(startedAt: at(2, 6, 0));
    rows = await history.watchAllHistory().first;
    expect(
      rows.map((AlarmHistoryData row) => row.startedAt),
      orderedEquals(<DateTime>[at(2, 6, 0), at(1, 6, 0)]),
    );
  });

  test('watchAllHistory reflects updates', () async {
    final int id = await insertRow(startedAt: at(1, 6, 0));
    final AlarmHistoryData? row = await history.getHistoryById(id);
    await history.updateHistory(
      row!.copyWith(
        result: AlarmResult.success.dbValue,
        stoppedAt: Value<DateTime?>(at(1, 6, 5)),
      ),
    );

    final List<AlarmHistoryData> rows =
        await history.watchAllHistory().first;
    expect(rows.single.result, AlarmResult.success.dbValue);
    expect(rows.single.stoppedAt, at(1, 6, 5));
  });

  test('deleting an alarm keeps its history', () async {
    final int alarmId = await alarms.createAlarm(
      AlarmsCompanion.insert(hour: 7, minute: 30),
    );
    await insertRow(alarmId: alarmId, startedAt: at(1, 6, 0));
    await insertRow(alarmId: alarmId, startedAt: at(2, 6, 0));

    expect(await alarms.deleteAlarm(alarmId), isTrue);

    final List<AlarmHistoryData> rows = await history.getAllHistory();
    expect(rows.length, 2);
    expect(
      rows.map((AlarmHistoryData row) => row.alarmId),
      everyElement(alarmId),
    );
  });

  test('all result types round-trip', () async {
    for (final AlarmResult result in AlarmResult.values) {
      await insertRow(
        startedAt: at(1, 6, result.index),
        stoppedAt: at(1, 7, result.index),
        result: result,
      );
    }

    final List<AlarmHistoryData> rows = await history.getAllHistory();
    expect(
      rows.map((AlarmHistoryData row) => row.result).toSet(),
      AlarmResult.values.map((AlarmResult r) => r.dbValue).toSet(),
    );
  });

  test('timestamps and nullable ids round-trip', () async {
    await insertRow(
      startedAt: at(4, 6, 2),
      stoppedAt: at(4, 6, 47),
    );
    await insertRow(alarmId: null, startedAt: at(5, 6, 0));

    final List<AlarmHistoryData> rows = await history.getAllHistory();
    final AlarmHistoryData stamped = rows.firstWhere(
      (AlarmHistoryData row) => row.stoppedAt != null,
    );
    expect(stamped.startedAt, at(4, 6, 2));
    expect(stamped.stoppedAt, at(4, 6, 47));
    final AlarmHistoryData unlinked = rows.firstWhere(
      (AlarmHistoryData row) => row.alarmId == null,
    );
    expect(unlinked.stoppedAt, isNull);
  });

  test('attempts and snoozeCount round-trip with zero defaults', () async {
    final int plainId = await insertRow(startedAt: at(1, 6, 0));
    final int busyId = await insertRow(
      startedAt: at(2, 6, 0),
      attempts: 3,
      snoozeCount: 2,
    );

    final AlarmHistoryData? plain = await history.getHistoryById(plainId);
    expect(plain!.attempts, 0);
    expect(plain.snoozeCount, 0);
    final AlarmHistoryData? busy = await history.getHistoryById(busyId);
    expect(busy!.attempts, 3);
    expect(busy.snoozeCount, 2);
  });
}
