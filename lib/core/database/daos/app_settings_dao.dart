// Data access object for the [AppSettings] table.
//
// The table is meant to contain exactly one row with `id = 1`.
// [getSettings] lazily creates that row with the schema defaults the first
// time it is called so the rest of the app can always read a valid value.

import 'package:drift/drift.dart';

import '../database.dart';
import '../tables.dart';

part 'app_settings_dao.g.dart';

@DriftAccessor(tables: [AppSettings])
class AppSettingsDao extends DatabaseAccessor<AppDatabase>
    with _$AppSettingsDaoMixin {
  AppSettingsDao(super.db);

  /// Returns the single settings row, creating it (with schema defaults)
  /// if it does not yet exist.
  Future<AppSetting> getSettings() async {
    final existing = await (select(appSettings)..where((t) => t.id.equals(1)))
        .getSingleOrNull();
    if (existing != null) {
      return existing;
    }
    await into(appSettings).insert(
      const AppSettingsCompanion(id: Value(1)),
    );
    return (select(appSettings)..where((t) => t.id.equals(1))).getSingle();
  }

  /// Writes the provided settings back to the single row (id = 1).
  Future<void> updateSettings(AppSettingsCompanion entry) {
    return (update(appSettings)..where((t) => t.id.equals(1))).write(entry);
  }
}
