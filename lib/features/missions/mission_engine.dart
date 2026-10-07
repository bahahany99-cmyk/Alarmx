// Mission engine (Phase 4): one alarm firing's mission session.
//
// [MissionSession] runs the validated, `orderIndex`-ordered missions of a
// single alarm firing. Rules (all deterministic):
//   - Missions execute strictly in list order: only the [current] (first
//     pending) mission can complete or be skipped.
//   - Required missions must complete; optional missions may complete or be
//     explicitly skipped via [skipMission]. Required missions can never be
//     skipped.
//   - Completion is idempotent: unknown ids, already-resolved missions,
//     out-of-order completions, and calls after [isComplete] are no-ops
//     returning `false`, so duplicate mission events can never advance the
//     session twice.
//   - Transient progress lives here only; nothing is persisted (the
//     `Missions` table holds configuration, not session state).
//
// The session is a [ChangeNotifier] so the ringing screen rebuilds on
// progress; it has no widget, database, or platform dependencies.

import 'package:flutter/foundation.dart';

import 'mission_config.dart';

/// Runs one alarm firing's missions; see the file docs.
class MissionSession extends ChangeNotifier {
  MissionSession(List<MissionEntry> entries)
      : _entries = List<MissionEntry>.unmodifiable(
          List<MissionEntry>.of(entries)
            ..sort((MissionEntry a, MissionEntry b) {
              final int byOrder = a.orderIndex.compareTo(b.orderIndex);
              return byOrder != 0 ? byOrder : a.id.compareTo(b.id);
            }),
        );

  final List<MissionEntry> _entries;
  final Set<int> _completedIds = <int>{};
  final Set<int> _skippedIds = <int>{};

  /// Missions in execution order.
  List<MissionEntry> get entries => _entries;

  int get totalCount => _entries.length;

  int get completedCount => _completedIds.length;

  int get skippedCount => _skippedIds.length;

  bool isCompleted(int missionId) => _completedIds.contains(missionId);

  bool isSkipped(int missionId) => _skippedIds.contains(missionId);

  /// First pending mission (neither completed nor skipped), or `null`
  /// when every mission is resolved.
  MissionEntry? get current {
    for (final MissionEntry entry in _entries) {
      if (!_completedIds.contains(entry.id) &&
          !_skippedIds.contains(entry.id)) {
        return entry;
      }
    }
    return null;
  }

  /// Index of [current] (== [totalCount] when everything is resolved).
  int get currentIndex {
    final MissionEntry? pending = current;
    return pending == null ? _entries.length : _entries.indexOf(pending);
  }

  /// True when every required mission completed and every mission is
  /// resolved (completed, or skipped when optional). An empty session is
  /// trivially complete.
  bool get isComplete {
    for (final MissionEntry entry in _entries) {
      if (entry.required && !_completedIds.contains(entry.id)) {
        return false;
      }
      if (!_completedIds.contains(entry.id) &&
          !_skippedIds.contains(entry.id)) {
        return false;
      }
    }
    return true;
  }

  /// Marks [missionId] complete. Only the [current] mission can complete;
  /// anything else is a no-op returning `false`.
  bool completeMission(int missionId) {
    if (isComplete || current?.id != missionId) {
      return false;
    }
    _completedIds.add(missionId);
    notifyListeners();
    return true;
  }

  /// Skips [missionId]. Only the [current] mission can be skipped, and
  /// only when it is optional; anything else is a no-op returning `false`.
  bool skipMission(int missionId) {
    if (isComplete || current?.id != missionId) {
      return false;
    }
    final MissionEntry? entry = _byId(missionId);
    if (entry == null || entry.required) {
      return false;
    }
    _skippedIds.add(missionId);
    notifyListeners();
    return true;
  }

  MissionEntry? _byId(int id) {
    for (final MissionEntry entry in _entries) {
      if (entry.id == id) {
        return entry;
      }
    }
    return null;
  }
}
