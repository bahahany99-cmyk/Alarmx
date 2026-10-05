// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'alarm_history_dao.dart';

// ignore_for_file: type=lint
mixin _$AlarmHistoryDaoMixin on DatabaseAccessor<AppDatabase> {
  $AlarmHistoryTable get alarmHistory => attachedDatabase.alarmHistory;
  AlarmHistoryDaoManager get managers => AlarmHistoryDaoManager(this);
}

class AlarmHistoryDaoManager {
  final _$AlarmHistoryDaoMixin _db;
  AlarmHistoryDaoManager(this._db);
  $$AlarmHistoryTableTableManager get alarmHistory =>
      $$AlarmHistoryTableTableManager(_db.attachedDatabase, _db.alarmHistory);
}
