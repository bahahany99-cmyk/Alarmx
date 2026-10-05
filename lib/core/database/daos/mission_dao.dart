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
}
