// Mission service (Phase 4).
//
// Validated mission-list operations above [MissionRepository]:
//   - [getMissionsForAlarm] loads the executable missions of one alarm in
//     `orderIndex` order, dropping `none` rows silently (inert by design)
//     and counting malformed/invalid rows so the ringing screen can warn
//     about skipped missions instead of crashing on them.
//   - [validateDrafts] is the pure pre-save check (message keys, empty
//     means valid). Callers validate BEFORE writing anything else so an
//     invalid mission list never leaves a half-written alarm behind.
//   - [saveMissionsForAlarm] normalizes `orderIndex` to 0...N-1, preserves
//     the `required` flag, serializes configs, and persists the whole list
//     atomically (see `MissionDao.replaceMissionsForAlarm`). An empty list
//     clears the alarm's missions, which is a valid state.
//
// The service throws [MissionValidationException] for invalid drafts
// (callers pre-validate and translate it to UI results); database errors
// propagate so callers can report them honestly.

import 'package:alarmx/core/database/database.dart';
import 'package:alarmx/core/models/models.dart';
import 'package:alarmx/core/repositories/mission_repository.dart';
import 'package:drift/drift.dart' show Value;

import 'mission_config.dart';

/// Executable missions of one alarm, in `orderIndex` order.
class AlarmMissions {
  const AlarmMissions({
    required this.entries,
    required this.invalidCount,
  });

  /// Validated missions, ordered for execution.
  final List<MissionEntry> entries;

  /// Stored rows skipped for malformed/invalid config (`none` rows are
  /// inert, not invalid, and are not counted here).
  final int invalidCount;
}

/// Thrown by [MissionService.saveMissionsForAlarm] for invalid drafts.
/// Carries [AppStrings] message keys, not display text.
class MissionValidationException implements Exception {
  MissionValidationException(this.messageKeys);

  final List<String> messageKeys;

  @override
  String toString() => 'MissionValidationException($messageKeys)';
}

/// Validated mission-list operations; see the file docs.
class MissionService {
  MissionService(this._repository);

  final MissionRepository _repository;

  /// Loads the alarm's executable missions; see [AlarmMissions].
  Future<AlarmMissions> getMissionsForAlarm(int alarmId) async {
    final List<Mission> rows = await _repository.getMissionsForAlarm(alarmId);
    final List<MissionEntry> entries = <MissionEntry>[];
    int invalid = 0;
    for (final Mission row in rows) {
      if (MissionType.fromDbValue(row.type) == MissionType.none) {
        continue;
      }
      final MissionEntry? entry = MissionEntry.tryFromRow(row);
      if (entry == null) {
        invalid++;
        continue;
      }
      entries.add(entry);
    }
    return AlarmMissions(entries: entries, invalidCount: invalid);
  }

  /// Pure pre-save validation of editor drafts. Returns the offending
  /// message keys (one per invalid draft); empty means the list is valid.
  static List<String> validateDrafts(List<MissionDraft> drafts) {
    final List<String> errors = <String>[];
    for (final MissionDraft draft in drafts) {
      final String? key = draft.validationMessageKey();
      if (key != null) {
        errors.add(key);
      }
    }
    return errors;
  }

  /// Atomically replaces the alarm's mission list with [drafts].
  ///
  /// Throws [MissionValidationException] without writing anything when a
  /// draft is invalid.
  Future<void> saveMissionsForAlarm(
    int alarmId,
    List<MissionDraft> drafts,
  ) async {
    final List<String> errors = validateDrafts(drafts);
    if (errors.isNotEmpty) {
      throw MissionValidationException(errors);
    }
    final List<MissionsCompanion> companions = <MissionsCompanion>[];
    for (int i = 0; i < drafts.length; i++) {
      final MissionDraft draft = drafts[i];
      companions.add(
        MissionsCompanion.insert(
          alarmId: alarmId,
          type: draft.type.dbValue,
          orderIndex: Value(i),
          configJson: Value(encodeMissionConfig(draft.config)),
          required: Value(draft.required),
        ),
      );
    }
    await _repository.replaceMissionsForAlarm(alarmId, companions);
  }
}
