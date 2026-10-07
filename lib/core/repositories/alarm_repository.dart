// Repository for user-defined alarms.
//
// Pure data access: create/read/update/delete over the `Alarms` table.
// Scheduling is NOT done here — the database stores the *desired* alarm
// state, and `NativeAlarmScheduler` (AlarmManager) performs the actual OS
// scheduling. DATABASE ≠ ALARM SCHEDULER.
//
// Typed columns are written with the models vocabulary, e.g.
// `AlarmsCompanion.insert(hour: ..., minute: ...,
// repeatType: Value(RepeatType.daily.dbValue))`; see `core/models/`.

import '../database/daos/alarm_dao.dart';
import '../database/database.dart';

/// Reads and writes user alarms.
abstract class AlarmRepository {
  /// Reactive stream of all alarms, in insertion order.
  Stream<List<Alarm>> watchAlarms();

  /// All alarms, read once, in insertion order.
  Future<List<Alarm>> getAlarms();

  /// The alarm with [id], or `null` when no such alarm exists.
  Future<Alarm?> getAlarmById(int id);

  /// All alarms whose `enabled` flag is currently true.
  Future<List<Alarm>> getEnabledAlarms();

  /// Inserts [entry] and returns the generated row id.
  Future<int> createAlarm(AlarmsCompanion entry);

  /// Replaces the stored row. Returns `false` when no row with that id exists.
  Future<bool> updateAlarm(Alarm entry);

  /// Enables or disables the alarm. Returns `false` when [id] does not exist.
  ///
  /// This only flips stored state; (un)scheduling with the OS is the
  /// caller's responsibility.
  Future<bool> setAlarmEnabled(int id, bool enabled);

  /// Deletes the alarm; its missions are removed by FK cascade.
  /// Returns `false` when [id] does not exist.
  ///
  /// This only deletes stored state; cancelling the OS schedule is the
  /// caller's responsibility.
  Future<bool> deleteAlarm(int id);
}

/// [AlarmRepository] backed by Drift.
class DriftAlarmRepository implements AlarmRepository {
  DriftAlarmRepository(this._dao);

  final AlarmDao _dao;

  @override
  Stream<List<Alarm>> watchAlarms() => _dao.watchAllAlarms();

  @override
  Future<List<Alarm>> getAlarms() => _dao.getAllAlarms();

  @override
  Future<Alarm?> getAlarmById(int id) => _dao.getAlarmById(id);

  @override
  Future<List<Alarm>> getEnabledAlarms() => _dao.getEnabledAlarms();

  @override
  Future<int> createAlarm(AlarmsCompanion entry) => _dao.insertAlarm(entry);

  @override
  Future<bool> updateAlarm(Alarm entry) => _dao.updateAlarm(entry);

  @override
  Future<bool> setAlarmEnabled(int id, bool enabled) async {
    final Alarm? current = await _dao.getAlarmById(id);
    if (current == null) {
      return false;
    }
    return _dao.updateAlarm(current.copyWith(enabled: enabled));
  }

  @override
  Future<bool> deleteAlarm(int id) async {
    final int removed = await _dao.deleteAlarm(id);
    return removed > 0;
  }
}
