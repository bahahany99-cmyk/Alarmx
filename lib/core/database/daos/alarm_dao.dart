// Data access object for the [Alarms] table.

import 'package:drift/drift.dart';

import '../database.dart';
import '../tables.dart';

part 'alarm_dao.g.dart';

@DriftAccessor(tables: [Alarms])
class AlarmDao extends DatabaseAccessor<AppDatabase> with _$AlarmDaoMixin {
  AlarmDao(super.db);

  /// Reactive stream of every alarm row, in insertion order.
  Stream<List<Alarm>> watchAllAlarms() {
    return (select(alarms)
          ..orderBy([(t) => OrderingTerm.asc(t.id)]))
        .watch();
  }

  /// Returns every alarm row, in insertion order.
  ///
  /// Direct one-shot read (no watch stream): prefer this over
  /// `watchAllAlarms().first`, whose cancel schedules drift's deferred
  /// stream-cache timer.
  Future<List<Alarm>> getAllAlarms() {
    return (select(alarms)
          ..orderBy([(t) => OrderingTerm.asc(t.id)]))
        .get();
  }

  /// Returns a single alarm by its primary key, or `null` if not found.
  Future<Alarm?> getAlarmById(int id) {
    return (select(alarms)..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  /// Inserts a new alarm and returns the generated row id.
  Future<int> insertAlarm(AlarmsCompanion entry) {
    return into(alarms).insert(entry);
  }

  /// Replaces the row with the same id as [entry].
  Future<bool> updateAlarm(Alarm entry) {
    return update(alarms).replace(entry);
  }

  /// Deletes the alarm with the given id. Returns true if a row was removed.
  Future<int> deleteAlarm(int id) {
    return (delete(alarms)..where((t) => t.id.equals(id))).go();
  }

  /// Returns all alarms whose `enabled` flag is currently true.
  Future<List<Alarm>> getEnabledAlarms() {
    return (select(alarms)..where((t) => t.enabled.equals(true))).get();
  }
}
