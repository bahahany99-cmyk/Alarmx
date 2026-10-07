// Ringing session orchestration (Phase 5).
//
// [RingingSession] owns one alarm ring end to end: it loads the alarm row,
// its missions (into a live `MissionSession`, read and never bypassed),
// and its history episode, then serves the three terminal actions:
//
//   RINGING -- mission success --> stop() --> stopped
//           -- valid snooze -----> snooze() --> snoozed
//           -- emergency exit ---> emergencyExit() --> emergency
//
// Ordering guarantees (all enforced by `await`, no locks):
//   - stop/emergency record history first, then stop natively, so the
//     post-fire handoff finds the fired token intact and chains the next
//     occurrence normally.
//   - snooze persists the temporary trigger (coordinator) and the episode
//     count/target (history) BEFORE stopping natively, so the handoff
//     finds a diverted token and stays out of the way.
//   - Strict Mode is enforced inside [stop]: the bridge is never called
//     while required missions are incomplete. Screen recreation rebuilds
//     a fresh session (incomplete by construction), so no navigation or
//     re-entry path can bypass the gate. Snooze and emergency never
//     consult the gate: snooze re-arms the same missions on the next
//     ring, and emergency is the explicit bypass.
//   - A committed snooze whose native stop failed retries through the
//     stop leg only (the schedule is never written twice); [stop] also
//     bypasses the strict gate then, because stopping only completes an
//     already-committed snooze whose missions re-arm on the next ring.
//
// Degradation (a ringing alarm must never strand the user): a missing or
// unreadable alarm row disables strict/snooze/history but keeps stop and
// emergency; a failed mission load keeps stop; failed history writes are
// logged and skipped; failed native stops surface a retry. Public methods
// never throw.

import 'dart:async' show unawaited;

import 'package:alarmx/core/alarms/strict_policy.dart';
import 'package:alarmx/core/database/database.dart';
import 'package:alarmx/core/models/alarm_result.dart';
import 'package:alarmx/core/repositories/alarm_history_repository.dart';
import 'package:alarmx/core/repositories/alarm_repository.dart';
import 'package:alarmx/core/scheduling/alarm_schedule_result.dart';
import 'package:alarmx/core/scheduling/alarm_scheduling_coordinator.dart';
import 'package:alarmx/core/scheduling/snooze_policy.dart';
import 'package:alarmx/features/missions/mission_engine.dart';
import 'package:alarmx/features/missions/mission_service.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/foundation.dart';

import 'ringing_alarm_bridge.dart';
import 'ringing_history.dart';
import 'ringing_launch.dart';

/// Terminal outcome of a ringing session.
enum RingingOutcome {
  /// No terminal action completed yet.
  none,

  /// The ring stopped normally (missions satisfied or not required).
  stopped,

  /// The ring snoozed (a temporary trigger waits).
  snoozed,

  /// The ring ended through Emergency Exit.
  emergency,
}

/// One alarm ring, from load to a terminal outcome; see the file docs.
class RingingSession extends ChangeNotifier {
  RingingSession({
    required this.launch,
    required AlarmRepository alarms,
    required MissionService missions,
    required AlarmHistoryRepository history,
    required AlarmSchedulingCoordinator coordinator,
    required RingingAlarmBridge bridge,
    DateTime Function()? clock,
  })  : _alarms = alarms,
        _missions = missions,
        _history = history,
        _coordinator = coordinator,
        _bridge = bridge,
        _clock = clock ?? DateTime.now;

  /// The native ring this session serves.
  final RingingLaunch launch;

  final AlarmRepository _alarms;
  final MissionService _missions;
  final AlarmHistoryRepository _history;
  final AlarmSchedulingCoordinator _coordinator;
  final RingingAlarmBridge _bridge;
  final DateTime Function() _clock;

  bool _loaded = false;
  bool _disposed = false;
  bool _isLoading = true;
  bool _loadFailed = false;
  Alarm? _alarm;
  MissionSession? _missionSession;
  int _invalidMissionCount = 0;
  int? _episodeId;
  int _usedSnoozes = 0;
  bool _isBusy = false;
  bool _snoozeCommitted = false;
  RingingOutcome _outcome = RingingOutcome.none;
  String? _errorKey;

  /// True until [load] finishes.
  bool get isLoading => _isLoading;

  /// True when the mission list could not be read (still stoppable).
  bool get loadFailed => _loadFailed;

  /// The alarm row, or `null` when missing/unreadable (degraded mode).
  Alarm? get alarm => _alarm;

  /// Live mission session, or `null` while loading / on load failure.
  MissionSession? get missionSession => _missionSession;

  /// Stored mission rows skipped as invalid during load.
  int get invalidMissionCount => _invalidMissionCount;

  /// This episode's history row id, or `null` when untracked.
  int? get episodeId => _episodeId;

  /// Snoozes already used in this episode.
  int get usedSnoozes => _usedSnoozes;

  /// True while a stop/snooze/emergency call is in flight.
  bool get isBusy => _isBusy;

  /// Terminal outcome once an action completes.
  RingingOutcome get outcome => _outcome;

  /// Message key of the last failure (retry UI), cleared on new attempts.
  String? get errorKey => _errorKey;

  /// Whether this ring is strict (unknown rows are treated as normal).
  bool get strictMode => _alarm?.strictMode ?? false;

  /// Whether the normal stop path may end the ring right now.
  bool get canStop {
    final MissionSession? session = _missionSession;
    return StrictModePolicy.canStop(
      strictMode: strictMode,
      loadFailed: _loadFailed,
      totalMissions: session?.totalCount ?? 0,
      sessionComplete: session?.isComplete ?? false,
    );
  }

  /// Whether snooze is currently offered (the coordinator revalidates).
  bool get canSnooze {
    final Alarm? alarm = _alarm;
    if (_isLoading || _isBusy || _outcome != RingingOutcome.none) {
      return false;
    }
    if (alarm == null || launch.triggerAtMillis == null) {
      return false;
    }
    return SnoozePolicy.canSnooze(
      enabled: alarm.snoozeEnabled,
      minutes: alarm.snoozeMinutes,
      maxCount: alarm.snoozeMaxCount,
      usedCount: _usedSnoozes,
    );
  }

  /// Snoozes left, or `null` when unlimited.
  int? get snoozesRemaining {
    final Alarm? alarm = _alarm;
    if (alarm == null) {
      return 0;
    }
    return SnoozePolicy.remainingSnoozes(
      maxCount: alarm.snoozeMaxCount,
      usedCount: _usedSnoozes,
    );
  }

  /// Loads the alarm, missions, and episode. Single-shot; later calls
  /// are no-ops (a recreated screen builds a new session). Never throws.
  Future<void> load() async {
    if (_loaded) {
      return;
    }
    _loaded = true;
    _notify();
    final DateTime now = _clock();
    Alarm? alarm;
    try {
      alarm = await _alarms.getAlarmById(launch.alarmId);
    } catch (_) {
      alarm = null;
    }
    AlarmMissions? missions;
    try {
      missions = await _missions.getMissionsForAlarm(launch.alarmId);
    } catch (_) {
      missions = null;
    }
    if (_disposed) {
      return;
    }
    _alarm = alarm;
    if (missions == null) {
      _loadFailed = true;
    } else {
      final MissionSession session = MissionSession(missions.entries)
        ..addListener(_onMissions);
      _missionSession = session;
      _invalidMissionCount = missions.invalidCount;
    }
    if (alarm != null) {
      await _resolveEpisode(now);
    }
    _isLoading = false;
    _notify();
  }

  /// Normal stop: strict-gated, then history + native stop. Returns true
  /// on success. Retry-safe: failures set [errorKey] for a retry UI.
  Future<bool> stop() async {
    if (_isBusy || _outcome != RingingOutcome.none || _isLoading) {
      return false;
    }
    if (!canStop && !_snoozeCommitted) {
      return false;
    }
    _isBusy = true;
    _errorKey = null;
    _notify();
    await _markEpisode(AlarmResult.success);
    try {
      await _bridge.stopRingingAlarm(launch.alarmId);
    } catch (_) {
      _isBusy = false;
      _errorKey = 'ringingStopFailed';
      _notify();
      return false;
    }
    _isBusy = false;
    _snoozeCommitted = false;
    _outcome = RingingOutcome.stopped;
    _notify();
    return true;
  }

  /// Snooze: schedule + record, then native stop. Returns true on
  /// success. Retry-safe: a committed snooze whose stop failed retries
  /// through the stop leg only (never schedules twice).
  Future<bool> snooze() async {
    if (_isBusy || _outcome != RingingOutcome.none || _isLoading) {
      return false;
    }
    final Alarm? alarm = _alarm;
    final int? token = launch.triggerAtMillis;
    if (!_snoozeCommitted) {
      if (alarm == null || token == null) {
        return false;
      }
      if (!SnoozePolicy.canSnooze(
        enabled: alarm.snoozeEnabled,
        minutes: alarm.snoozeMinutes,
        maxCount: alarm.snoozeMaxCount,
        usedCount: _usedSnoozes,
      )) {
        return false;
      }
      _isBusy = true;
      _errorKey = null;
      _notify();
      final AlarmScheduleResult scheduled;
      try {
        scheduled = await _coordinator.snoozeAlarm(
          alarmId: launch.alarmId,
          firedTriggerAt: DateTime.fromMillisecondsSinceEpoch(token),
          now: _clock(),
        );
      } catch (_) {
        // Defensive: the coordinator never throws for domain failures.
        _isBusy = false;
        _errorKey = 'msgSnoozeFailed';
        _notify();
        return false;
      }
      if (scheduled is! AlarmScheduled) {
        _isBusy = false;
        _errorKey = 'msgSnoozeFailed';
        _notify();
        return false;
      }
      await _recordSnooze(scheduled.triggerAt);
      _snoozeCommitted = true;
      _usedSnoozes += 1;
    } else {
      _isBusy = true;
      _errorKey = null;
      _notify();
    }
    try {
      await _bridge.stopRingingAlarm(launch.alarmId);
    } catch (_) {
      _isBusy = false;
      _errorKey = 'ringingStopFailed';
      _notify();
      return false;
    }
    _isBusy = false;
    _outcome = RingingOutcome.snoozed;
    _notify();
    return true;
  }

  /// Emergency Exit: record the emergency result, then native stop.
  /// Available even while loading and without an alarm row. Retry-safe.
  Future<bool> emergencyExit() async {
    if (_isBusy || _outcome != RingingOutcome.none) {
      return false;
    }
    _isBusy = true;
    _errorKey = null;
    _notify();
    await _markEpisode(AlarmResult.emergencyStop);
    try {
      await _bridge.stopRingingAlarm(launch.alarmId);
    } catch (_) {
      _isBusy = false;
      _errorKey = 'ringingStopFailed';
      _notify();
      return false;
    }
    _isBusy = false;
    _outcome = RingingOutcome.emergency;
    _notify();
    return true;
  }

  void _onMissions() {
    final MissionSession? session = _missionSession;
    if (_disposed || session == null) {
      return;
    }
    if (session.isComplete &&
        _outcome == RingingOutcome.none &&
        !_isBusy &&
        !_isLoading) {
      // Mission success auto-stops the ring; stop() never throws.
      unawaited(stop());
    } else {
      _notify();
    }
  }

  /// Links this ring to its episode row (see `ringing_history.dart`).
  /// Failures degrade to untracked (no episode id, zero used snoozes).
  Future<void> _resolveEpisode(DateTime now) async {
    final int alarmId = launch.alarmId;
    List<AlarmHistoryData> rows;
    try {
      rows = await _history.getHistoryForAlarm(alarmId);
    } catch (_) {
      return;
    }
    final RingHistoryResolution resolution = resolveRingHistory(
      rowsNewestFirst: rows,
      firedTriggerMillis: launch.triggerAtMillis,
    );
    try {
      switch (resolution.action) {
        case RingHistoryAction.reuse:
          final AlarmHistoryData row = resolution.row!;
          _episodeId = row.id;
          _usedSnoozes = row.snoozeCount;
        case RingHistoryAction.closeStaleAndStart:
          final AlarmHistoryData stale = resolution.row!;
          await _history.updateHistory(
            stale.copyWith(
              result: AlarmResult.failed.dbValue,
              stoppedAt: Value<DateTime?>(now),
            ),
          );
          _episodeId = await _history.insertHistory(
            _freshEpisode(alarmId, now),
          );
          _usedSnoozes = 0;
        case RingHistoryAction.startFresh:
          _episodeId = await _history.insertHistory(
            _freshEpisode(alarmId, now),
          );
          _usedSnoozes = 0;
      }
    } catch (_) {
      _episodeId = null;
      _usedSnoozes = 0;
    }
    if (_usedSnoozes < 0) {
      _usedSnoozes = 0;
    }
  }

  AlarmHistoryCompanion _freshEpisode(int alarmId, DateTime now) {
    return AlarmHistoryCompanion.insert(
      alarmId: Value<int?>(alarmId),
      startedAt: now,
      result: Value<String>(AlarmResult.ongoing.dbValue),
    );
  }

  /// Records a terminal episode result. Failures are skipped: history is
  /// bookkeeping, and the ring must still stop.
  Future<void> _markEpisode(AlarmResult result) async {
    final int? id = _episodeId;
    if (id == null) {
      return;
    }
    try {
      final AlarmHistoryData? row = await _history.getHistoryById(id);
      if (row == null) {
        return;
      }
      await _history.updateHistory(
        row.copyWith(
          result: result.dbValue,
          stoppedAt: Value<DateTime?>(_clock()),
        ),
      );
    } catch (_) {
      // History is bookkeeping; the ring must still stop.
    }
  }

  /// Records a committed snooze (count + pending target) on the episode.
  /// Failures are skipped: the snooze is already scheduled, and stopping
  /// still completes it.
  Future<void> _recordSnooze(DateTime target) async {
    final int? id = _episodeId;
    if (id == null) {
      return;
    }
    try {
      final AlarmHistoryData? row = await _history.getHistoryById(id);
      if (row == null) {
        return;
      }
      await _history.updateHistory(
        row.copyWith(
          snoozeCount: row.snoozeCount + 1,
          stoppedAt: Value<DateTime?>(target),
        ),
      );
    } catch (_) {
      // The snooze is already scheduled; stopping still completes it.
    }
  }

  void _notify() {
    if (!_disposed) {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _missionSession?.removeListener(_onMissions);
    _missionSession?.dispose();
    _missionSession = null;
    super.dispose();
  }
}
