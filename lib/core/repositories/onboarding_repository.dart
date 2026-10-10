// Onboarding completion persistence over a raw-SQL side table.
//
// Why raw SQL instead of a typed Drift table: adding a column to the
// typed AppSettings table requires regenerating Drift codegen (*.g.dart
// via build_runner), which the current toolchain cannot run; hand-editing
// the ~43 generated sites around sensitive PIN/Strict Mode state was
// judged disproportionate risk for one independent boolean. This
// single-row table is created lazily with CREATE TABLE IF NOT EXISTS,
// fully isolated from the typed schema: no schema version bump, no
// migration step, zero edits to generated code.
//
// The flag answers exactly one question: did the first-run onboarding
// flow complete to the end? Fresh installs, reinstalls, and cleared app
// data all start from "not completed" (no row, or completed = 0).

import 'package:drift/drift.dart';

import '../database/database.dart';

/// Reads and writes the onboarding-completed flag.
abstract class OnboardingRepository {
  /// Returns true once the first-run onboarding flow completed to the end.
  /// False (the default) on fresh installs and until the flow finishes.
  Future<bool> isOnboardingComplete();

  /// Marks onboarding complete. Idempotent.
  Future<void> setOnboardingComplete();
}

/// [OnboardingRepository] over the `onboarding_state` side table.
class DriftOnboardingRepository implements OnboardingRepository {
  DriftOnboardingRepository(this._db);

  final AppDatabase _db;

  @override
  Future<bool> isOnboardingComplete() async {
    await _ensureTable();
    await _db.customStatement(
      'INSERT OR IGNORE INTO onboarding_state (id, completed) VALUES (1, 0)',
    );
    final QueryRow? row = await _db
        .customSelect('SELECT completed FROM onboarding_state WHERE id = 1')
        .getSingleOrNull();
    return (row?.read<int>('completed') ?? 0) == 1;
  }

  @override
  Future<void> setOnboardingComplete() async {
    await _ensureTable();
    await _db.customStatement(
      'INSERT INTO onboarding_state (id, completed) VALUES (1, 1) '
      'ON CONFLICT(id) DO UPDATE SET completed = 1',
    );
  }

  /// Creates the side table when missing. Independent of
  /// [MigrationStrategy]: idempotent by construction, so it is safe on
  /// fresh installs, upgrades, and in-memory test databases alike.
  Future<void> _ensureTable() {
    return _db.customStatement(
      'CREATE TABLE IF NOT EXISTS onboarding_state ('
      'id INTEGER PRIMARY KEY CHECK (id = 1), '
      'completed INTEGER NOT NULL DEFAULT 0)',
    );
  }
}
