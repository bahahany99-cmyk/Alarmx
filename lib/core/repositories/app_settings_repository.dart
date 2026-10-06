// Repository for application-wide settings.
//
// Pure data access over the single-row `AppSettings` table (row id = 1).
// [AppSettingsRepository.getSettings] always returns a valid row, creating
// it with schema defaults on first use.

import '../database/daos/app_settings_dao.dart';
import '../database/database.dart';

/// Reads and writes the global settings row.
abstract class AppSettingsRepository {
  /// Returns the settings row, creating it with schema defaults when missing.
  Future<AppSetting> getSettings();

  /// Writes [entry] back to the settings row.
  Future<void> updateSettings(AppSettingsCompanion entry);
}

/// [AppSettingsRepository] backed by Drift.
class DriftAppSettingsRepository implements AppSettingsRepository {
  DriftAppSettingsRepository(this._dao);

  final AppSettingsDao _dao;

  @override
  Future<AppSetting> getSettings() => _dao.getSettings();

  @override
  Future<void> updateSettings(AppSettingsCompanion entry) =>
      _dao.updateSettings(entry);
}
