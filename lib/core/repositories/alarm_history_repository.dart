// Repository for the alarm firing history log.
//
// Pure data access over the `AlarmHistory` table. History is append-only:
// entries are inserted when an alarm starts ringing and updated when the
// episode ends. There is intentionally no delete API; history rows survive
// their alarm (the `alarmId` column is a plain integer, not a FK).
//
// The outcome is written with the models vocabulary, e.g.
// `AlarmHistoryCompanion.insert(startedAt: ...,
// result: Value(AlarmResult.success.dbValue))`; see `core/models/`.

import '../database/daos/alarm_history_dao.dart';
import '../database/database.dart';

/// Reads and writes alarm history entries.
abstract class AlarmHistoryRepository {
  /// Inserts [entry] and returns the generated row id.
  Future<int> insertHistory(AlarmHistoryCompanion entry);

  /// Replaces the stored row. Returns `false` when no row with that id exists.
  Future<bool> updateHistory(AlarmHistoryData entry);

  /// The history entry with [id], or `null` when no such entry exists.
  Future<AlarmHistoryData?> getHistoryById(int id);

  /// Every history row for [alarmId], newest first.
  Future<List<AlarmHistoryData>> getHistoryForAlarm(int alarmId);

  /// Every history row in the table, newest first.
  Future<List<AlarmHistoryData>> getAllHistory();
}

/// [AlarmHistoryRepository] backed by Drift.
class DriftAlarmHistoryRepository implements AlarmHistoryRepository {
  DriftAlarmHistoryRepository(this._dao);

  final AlarmHistoryDao _dao;

  @override
  Future<int> insertHistory(AlarmHistoryCompanion entry) =>
      _dao.insertHistoryEntry(entry);

  @override
  Future<bool> updateHistory(AlarmHistoryData entry) =>
      _dao.updateHistoryEntry(entry);

  @override
  Future<AlarmHistoryData?> getHistoryById(int id) => _dao.getHistoryById(id);

  @override
  Future<List<AlarmHistoryData>> getHistoryForAlarm(int alarmId) =>
      _dao.getHistoryForAlarm(alarmId);

  @override
  Future<List<AlarmHistoryData>> getAllHistory() => _dao.getAllHistory();
}
