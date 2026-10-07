// Repository for dismiss missions attached to alarms.
//
// Pure data access over the `Missions` table. Mission *logic* (math tasks,
// QR scanning, ...) is implemented in later phases; this layer only stores
// and retrieves the mission rows and their JSON configuration.
//
// The mission type is written with the models vocabulary, e.g.
// `MissionsCompanion.insert(alarmId: ..., type: MissionType.math.dbValue)`;
// see `core/models/`.

import '../database/daos/mission_dao.dart';
import '../database/database.dart';

/// Reads and writes dismiss missions.
abstract class MissionRepository {
  /// All missions attached to [alarmId], in execution order.
  /// Returns an empty list when the alarm has no missions.
  Future<List<Mission>> getMissionsForAlarm(int alarmId);

  /// The mission with [id], or `null` when no such mission exists.
  Future<Mission?> getMissionById(int id);

  /// Inserts [entry] and returns the generated row id.
  Future<int> createMission(MissionsCompanion entry);

  /// Replaces the stored row. Returns `false` when no row with that id exists.
  Future<bool> updateMission(Mission entry);

  /// Deletes the mission. Returns `false` when [id] does not exist.
  Future<bool> deleteMission(int id);

  /// Deletes every mission attached to [alarmId]. Returns the removed count.
  Future<int> deleteMissionsForAlarm(int alarmId);

  /// Atomically replaces the alarm's mission list with [entries].
  /// An empty list clears the alarm's missions (a valid state).
  Future<void> replaceMissionsForAlarm(
    int alarmId,
    List<MissionsCompanion> entries,
  );
}

/// [MissionRepository] backed by Drift.
class DriftMissionRepository implements MissionRepository {
  DriftMissionRepository(this._dao);

  final MissionDao _dao;

  @override
  Future<List<Mission>> getMissionsForAlarm(int alarmId) =>
      _dao.getMissionsForAlarm(alarmId);

  @override
  Future<Mission?> getMissionById(int id) => _dao.getMissionById(id);

  @override
  Future<int> createMission(MissionsCompanion entry) =>
      _dao.insertMission(entry);

  @override
  Future<bool> updateMission(Mission entry) => _dao.updateMission(entry);

  @override
  Future<bool> deleteMission(int id) async {
    final int removed = await _dao.deleteMission(id);
    return removed > 0;
  }

  @override
  Future<int> deleteMissionsForAlarm(int alarmId) =>
      _dao.deleteMissionsForAlarm(alarmId);

  @override
  Future<void> replaceMissionsForAlarm(
    int alarmId,
    List<MissionsCompanion> entries,
  ) =>
      _dao.replaceMissionsForAlarm(alarmId, entries);
}
