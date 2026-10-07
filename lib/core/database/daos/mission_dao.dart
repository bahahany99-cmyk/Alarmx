// Data access object for the [Missions] table.

import 'package:drift/drift.dart';

import '../database.dart';
import '../tables.dart';

part 'mission_dao.g.dart';

@DriftAccessor(tables: [Missions])
class MissionDao extends DatabaseAccessor<AppDatabase> with _$MissionDaoMixin {
  MissionDao(super.db);

  /// Returns all missions attached to [alarmId], ordered by [orderIndex]
  /// ascending and then by id ascending to make the order deterministic.
  Future<List<Mission>> getMissionsForAlarm(int alarmId) {
    return (select(missions)
          ..where((t) => t.alarmId.equals(alarmId))
          ..orderBy([
            (t) => OrderingTerm.asc(t.orderIndex),
            (t) => OrderingTerm.asc(t.id),
          ]))
        .get();
  }

  /// Inserts a new mission and returns the generated row id.
  Future<int> insertMission(MissionsCompanion entry) {
    return into(missions).insert(entry);
  }

  /// Returns a single mission by its primary key, or `null` if not found.
  Future<Mission?> getMissionById(int id) {
    return (select(missions)..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  /// Replaces the row with the same id as [entry].
  Future<bool> updateMission(Mission entry) {
    return update(missions).replace(entry);
  }

  /// Deletes every mission attached to [alarmId]. Returns the row count
  /// removed. Used when an alarm is deleted (FK cascade also handles this,
  /// but the method is provided as an explicit bulk operation).
  Future<int> deleteMissionsForAlarm(int alarmId) {
    return (delete(missions)..where((t) => t.alarmId.equals(alarmId))).go();
  }

  /// Deletes the mission with the given id. Returns the removed row count
  /// (`0` when no mission with that id exists).
  Future<int> deleteMission(int id) {
    return (delete(missions)..where((t) => t.id.equals(id))).go();
  }

  /// Atomically replaces every mission of [alarmId] with [entries].
  ///
  /// Runs inside a single transaction: either the whole list is replaced
  /// or the stored list is untouched. An empty [entries] clears the
  /// alarm's missions (a valid state: "no missions" needs no rows).
  Future<void> replaceMissionsForAlarm(
    int alarmId,
    List<MissionsCompanion> entries,
  ) {
    return attachedDatabase.transaction(() async {
      await (delete(missions)..where((t) => t.alarmId.equals(alarmId))).go();
      for (final MissionsCompanion entry in entries) {
        await into(missions).insert(entry);
      }
    });
  }
}
