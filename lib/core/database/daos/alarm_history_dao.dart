// Data access object for the [AlarmHistory] table.

import 'package:drift/drift.dart';

import '../database.dart';
import '../tables.dart';

part 'alarm_history_dao.g.dart';

@DriftAccessor(tables: [AlarmHistory])
class AlarmHistoryDao extends DatabaseAccessor<AppDatabase>
    with _$AlarmHistoryDaoMixin {
  AlarmHistoryDao(super.db);

  /// Inserts a new history entry and returns the generated row id.
  Future<int> insertHistoryEntry(AlarmHistoryCompanion entry) {
    return into(alarmHistory).insert(entry);
  }

  /// Replaces the row with the same id as [entry].
  Future<bool> updateHistoryEntry(AlarmHistoryData entry) {
    return update(alarmHistory).replace(entry);
  }

  /// Returns a single history entry by its primary key, or `null` if not found.
  Future<AlarmHistoryData?> getHistoryById(int id) {
    return (select(alarmHistory)..where((t) => t.id.equals(id)))
        .getSingleOrNull();
  }

  /// Returns every history row for the given [alarmId], newest first.
  Future<List<AlarmHistoryData>> getHistoryForAlarm(int alarmId) {
    return (select(alarmHistory)
          ..where((t) => t.alarmId.equals(alarmId))
          ..orderBy([(t) => OrderingTerm.desc(t.startedAt)]))
        .get();
  }

  /// Returns every history row in the table, newest first.
  Future<List<AlarmHistoryData>> getAllHistory() {
    return (select(alarmHistory)
          ..orderBy([(t) => OrderingTerm.desc(t.startedAt)]))
        .get();
  }
}
