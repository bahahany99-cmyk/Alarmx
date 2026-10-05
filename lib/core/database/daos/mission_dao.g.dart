// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'mission_dao.dart';

// ignore_for_file: type=lint
mixin _$MissionDaoMixin on DatabaseAccessor<AppDatabase> {
  $AlarmsTable get alarms => attachedDatabase.alarms;
  $MissionsTable get missions => attachedDatabase.missions;
  MissionDaoManager get managers => MissionDaoManager(this);
}

class MissionDaoManager {
  final _$MissionDaoMixin _db;
  MissionDaoManager(this._db);
  $$AlarmsTableTableManager get alarms =>
      $$AlarmsTableTableManager(_db.attachedDatabase, _db.alarms);
  $$MissionsTableTableManager get missions =>
      $$MissionsTableTableManager(_db.attachedDatabase, _db.missions);
}
