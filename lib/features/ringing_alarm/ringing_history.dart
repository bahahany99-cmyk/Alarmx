// Ring-episode history linkage (Phase 5).
//
// Every ring cold-boots Dart, so the snooze count must round-trip through
// the existing `AlarmHistory` table: each episode (initial ring plus its
// snoozed continuations) owns exactly one row while open.
//
// Liveness keys on `result == 'ongoing'` ONLY — never on `stoppedAt`:
// while a snooze waits, `stoppedAt` transiently holds the pending snooze
// target (millis) so the next ring can prove it continues this episode.
// Completion overwrites it with the actual end time, so closed rows keep
// their natural meaning (`startedAt` = first ring, `stoppedAt` = end).
//
// [resolveRingHistory] links a fresh ring to its row: the latest row is
// reused only when it is open AND its pending target equals the fired
// token; anything else starts a fresh episode (a stale open row is
// reported for closing as `failed`, so counts never leak across
// unrelated occurrences and zombie rows never accumulate).

import 'package:alarmx/core/database/database.dart';
import 'package:alarmx/core/models/alarm_result.dart';

/// How a fresh ring relates to the alarm's stored history.
enum RingHistoryAction {
  /// The ring continues [RingHistoryResolution.row]'s episode.
  reuse,

  /// [RingHistoryResolution.row] is a stale leftover: close it as failed,
  /// then start a fresh episode row.
  closeStaleAndStart,

  /// No usable row exists: start a fresh episode row.
  startFresh,
}

/// Pure result of [resolveRingHistory]; the caller performs the writes.
class RingHistoryResolution {
  const RingHistoryResolution(this.action, this.row);

  final RingHistoryAction action;

  /// The open row to reuse or close; `null` for [RingHistoryAction.startFresh].
  final AlarmHistoryData? row;
}

/// Links the ring that fired [firedTriggerMillis] to its episode row.
///
/// [rowsNewestFirst] is the alarm's history, newest first, as returned by
/// the repository. Only the newest row can own an open episode; older
/// rows are never resurrected. A `null` token (legacy ring) never reuses:
/// an unverified continuation must not inherit another ring's count.
/// Pure; never throws.
RingHistoryResolution resolveRingHistory({
  required List<AlarmHistoryData> rowsNewestFirst,
  required int? firedTriggerMillis,
}) {
  if (rowsNewestFirst.isEmpty) {
    return const RingHistoryResolution(RingHistoryAction.startFresh, null);
  }
  final AlarmHistoryData latest = rowsNewestFirst.first;
  if (latest.result != AlarmResult.ongoing.dbValue) {
    return const RingHistoryResolution(RingHistoryAction.startFresh, null);
  }
  if (firedTriggerMillis == null) {
    return RingHistoryResolution(
      RingHistoryAction.closeStaleAndStart,
      latest,
    );
  }
  final int? pendingTarget = latest.stoppedAt?.millisecondsSinceEpoch;
  if (pendingTarget != null && pendingTarget == firedTriggerMillis) {
    return RingHistoryResolution(RingHistoryAction.reuse, latest);
  }
  return RingHistoryResolution(
    RingHistoryAction.closeStaleAndStart,
    latest,
  );
}
