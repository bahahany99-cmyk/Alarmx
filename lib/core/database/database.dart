// AlarmX application database.
//
// Wires up the four Drift tables (defined in [tables.dart]) and the four
// DAOs (defined in `daos/`). The schema is at version 1; bump the
// version and add a migration step when the schema changes.
//
// The native connection is created by the `drift_flutter` package, which
// resolves to a NativeDatabase on Android/iOS/macOS/Linux/Windows (storing
// the file in the application documents directory) and to a web worker on
// the web. The database file is named `alarmx.sqlite` per the project spec.

import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import 'daos/alarm_dao.dart';
import 'daos/alarm_history_dao.dart';
import 'daos/app_settings_dao.dart';
import 'daos/mission_dao.dart';
import 'tables.dart';

part 'database.g.dart';

@DriftDatabase(
  tables: [Alarms, Missions, AlarmHistory, AppSettings],
  daos: [AlarmDao, MissionDao, AlarmHistoryDao, AppSettingsDao],
)
class AppDatabase extends _$AppDatabase {
  /// Default constructor used by production code. Uses `drift_flutter` to
  /// open a `alarmx.sqlite` file in the application documents directory.
  AppDatabase() : super(driftDatabase(name: 'alarmx'));

  /// Constructor used by tests that want to inject an in-memory connection
  /// (e.g. via `AppDatabase.connect(NativeDatabase.memory())`).
  AppDatabase.connect(super.connection);

  @override
  int get schemaVersion => 1;

  /// Migration strategy.
  ///
  /// Version history:
  ///   - v1: baseline — the four tables in `tables.dart`, created by
  ///     [Migrator.createAll]. There are no shipped users yet, so no upgrade
  ///     path exists. When `schemaVersion` is bumped, add an explicit
  ///     `onUpgrade` step here for every version jump (never rely on the
  ///     default destructive fallback once the app is released).
  ///
  /// [MigrationStrategy.beforeOpen] enables foreign-key enforcement on every
  /// connection (including in-memory test databases), which is what makes
  /// the declared `Missions.alarmId ... ON DELETE CASCADE` actually work —
  /// SQLite does not enforce foreign keys unless this pragma is set.
  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (Migrator m) async {
        await m.createAll();
      },
      beforeOpen: (OpeningDetails details) async {
        await customStatement('PRAGMA foreign_keys = ON');
      },
    );
  }
}
