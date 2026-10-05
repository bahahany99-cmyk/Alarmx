// Drift table definitions for AlarmX.
//
// All tables are defined in Dart (not in .drift files) by extending the
// `Table` class. The Drift code generator (`build_runner`) produces the
// corresponding row data classes and companion classes used by the DAOs:
//   Alarms         -> row class `Alarm`,           companion `AlarmsCompanion`
//   Missions       -> row class `Mission`,         companion `MissionsCompanion`
//   AlarmHistory   -> row class `AlarmHistoryData`, companion `AlarmHistoryCompanion`
//   AppSettings    -> row class `AppSetting`,      companion `AppSettingsCompanion`
//
// String columns that hold an enum-like value are not encoded as Dart enums
// at the storage layer — the allowed values are documented inline so the
// schema can be migrated without breaking on-disk data.

import 'package:drift/drift.dart';

/// User-defined alarms.
///
/// `repeatType` is one of: 'once', 'daily', 'custom'.
/// `repeatDays` is a 7-bit bitmask used only when `repeatType = 'custom'`,
/// where bit 0 = Sunday, bit 1 = Monday, ..., bit 6 = Saturday (mask 0..127).
/// `onceDate` is used only when `repeatType = 'once'`.
///
/// `nextTriggerAt` is the precomputed next fire time and is critical for the
/// native scheduler — the platform alarm will be scheduled at this time and
/// business logic is responsible for keeping the value in sync.
@DataClassName('Alarm')
class Alarms extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get label => text().nullable()();

  IntColumn get hour => integer()();
  IntColumn get minute => integer()();

  BoolColumn get enabled => boolean().withDefault(const Constant(true))();

  TextColumn get repeatType =>
      text().withDefault(const Constant('once'))();

  IntColumn get repeatDays => integer().nullable()();

  DateTimeColumn get onceDate => dateTime().nullable()();

  TextColumn get soundUri => text().nullable()();
  TextColumn get soundType =>
      text().withDefault(const Constant('default'))();

  IntColumn get volume => integer().withDefault(const Constant(80))();

  BoolColumn get fadeInEnabled =>
      boolean().withDefault(const Constant(false))();
  BoolColumn get vibrationEnabled =>
      boolean().withDefault(const Constant(true))();
  BoolColumn get snoozeEnabled =>
      boolean().withDefault(const Constant(true))();

  IntColumn get snoozeMinutes => integer().withDefault(const Constant(5))();
  IntColumn get snoozeMaxCount => integer().withDefault(const Constant(3))();

  BoolColumn get strictMode =>
      boolean().withDefault(const Constant(false))();

  DateTimeColumn get nextTriggerAt => dateTime().nullable()();

  DateTimeColumn get createdAt =>
      dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt =>
      dateTime().withDefault(currentDateAndTime)();
}

/// Mission attached to an alarm.
///
/// `type` is one of: 'none', 'math', 'qr', 'barcode', 'photo', 'typing', 'shake'.
/// `configJson` stores the type-specific configuration as a JSON string
/// (e.g. math difficulty/count, QR expected value, typing expected text,
/// shake required count). It is nullable so a 'none' mission can omit it.
@DataClassName('Mission')
class Missions extends Table {
  IntColumn get id => integer().autoIncrement()();

  IntColumn get alarmId =>
      integer().references(Alarms, #id, onDelete: KeyAction.cascade)();

  TextColumn get type => text()();

  IntColumn get orderIndex => integer().withDefault(const Constant(0))();

  TextColumn get configJson => text().nullable()();

  BoolColumn get required => boolean().withDefault(const Constant(true))();
}

/// History of an alarm firing.
///
/// `alarmId` is intentionally NOT a foreign key: alarms can be deleted
/// later while their history rows are preserved, so we keep this column
/// as a plain nullable integer.
///
/// `result` is one of: 'ongoing', 'success', 'emergency_stop', 'failed'.
@DataClassName('AlarmHistoryData')
class AlarmHistory extends Table {
  IntColumn get id => integer().autoIncrement()();

  IntColumn get alarmId => integer().nullable()();

  DateTimeColumn get startedAt => dateTime()();
  DateTimeColumn get stoppedAt => dateTime().nullable()();

  TextColumn get result => text().withDefault(const Constant('ongoing'))();

  IntColumn get attempts => integer().withDefault(const Constant(0))();
  IntColumn get snoozeCount => integer().withDefault(const Constant(0))();
}

/// Application-wide settings.
///
/// The table is intended to contain exactly one row with `id = 1`. The
/// `AppSettingsDao` is responsible for creating the row on first read if
/// it does not exist.
///
/// `language` defaults to 'ar' (Arabic). `theme` defaults to 'system'.
@DataClassName('AppSetting')
class AppSettings extends Table {
  IntColumn get id => integer()();

  BoolColumn get strictModeDefault =>
      boolean().withDefault(const Constant(false))();
  BoolColumn get pinEnabled => boolean().withDefault(const Constant(false))();

  TextColumn get pinHash => text().nullable()();

  TextColumn get defaultSound => text().nullable()();
  IntColumn get defaultVolume => integer().withDefault(const Constant(80))();

  TextColumn get language => text().withDefault(const Constant('ar'))();
  TextColumn get theme => text().withDefault(const Constant('system'))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}
