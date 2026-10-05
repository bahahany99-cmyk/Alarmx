// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'alarm_dao.dart';

// ignore_for_file: type=lint
mixin _$AlarmDaoMixin on DatabaseAccessor<AppDatabase> {
  $AlarmsTable get alarms => attachedDatabase.alarms;
  AlarmDaoManager get managers => AlarmDaoManager(this);
}

class AlarmDaoManager {
  final _$AlarmDaoMixin _db;
  AlarmDaoManager(this._db);
  $$AlarmsTableTableManager get alarms =>
      $$AlarmsTableTableManager(_db.attachedDatabase, _db.alarms);
}
