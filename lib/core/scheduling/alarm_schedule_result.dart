// Outcomes of [AlarmSchedulingCoordinator] scheduling operations.
//
// The schedule family (`scheduleAlarm`, `enableAlarm`, `rescheduleAlarm`)
// never throws for domain or scheduler failures: every outcome — success,
// nothing-to-schedule, disabled, missing permission, failure — is returned
// as an [AlarmScheduleResult] so future UI code can branch on it with an
// exhaustive switch. (`cancelAlarm`/`disableAlarm` are fire-and-forget state
// changes and report programmer/bridge errors by throwing instead; see the
// coordinator docs.)

/// Result of asking the coordinator to (re)schedule an alarm.
sealed class AlarmScheduleResult {
  const AlarmScheduleResult();
}

/// The alarm is now scheduled with the OS at [triggerAt].
///
/// The trigger was also persisted to the alarm's `nextTriggerAt` field, so
/// the database and the OS schedule agree.
final class AlarmScheduled extends AlarmScheduleResult {
  const AlarmScheduled(this.triggerAt);

  /// Exact local trigger time handed to the native scheduler.
  final DateTime triggerAt;
}

/// Nothing was scheduled: the alarm has no upcoming occurrence.
///
/// This happens for one-time alarms in the past (or without a date) and for
/// selected-weekdays alarms with no day selected. Any previous native
/// schedule for the alarm was cancelled and its `nextTriggerAt` cleared.
final class AlarmNotSchedulable extends AlarmScheduleResult {
  const AlarmNotSchedulable(this.reason);

  /// Human-readable reason, e.g. for future UI messaging/logging.
  final String reason;
}

/// Nothing was scheduled: the alarm is disabled in the database.
///
/// Any previous native schedule for the alarm was cancelled and its
/// `nextTriggerAt` cleared.
final class AlarmDisabled extends AlarmScheduleResult {
  const AlarmDisabled();
}

/// Nothing was scheduled: the OS currently forbids exact alarms.
///
/// On Android 12+ this means the user revoked the exact-alarm permission;
/// the future UI should route to Settings and let the user retry. Any
/// previous native schedule for the alarm was cancelled and its
/// `nextTriggerAt` cleared (a revoked permission stops previously scheduled
/// exact alarms from firing anyway).
final class AlarmPermissionMissing extends AlarmScheduleResult {
  const AlarmPermissionMissing();
}

/// Scheduling failed with [error] (scheduler/bridge or database error).
///
/// The operation is never reported as successful: either nothing is
/// scheduled, or — only when persisting a just-created native schedule
/// failed *and* the rollback cancel failed too — [scheduledButNotPersisted]
/// names the leaked native trigger so a future reconcile pass can cancel it.
final class AlarmScheduleFailed extends AlarmScheduleResult {
  const AlarmScheduleFailed(this.error, {this.scheduledButNotPersisted});

  /// The underlying exception.
  final Object error;

  /// Non-null only when a native schedule exists that the database does
  /// not know about (persist + rollback both failed). Null otherwise.
  final DateTime? scheduledButNotPersisted;
}
