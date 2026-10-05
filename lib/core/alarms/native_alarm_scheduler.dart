// Abstract interface for the native alarm scheduling bridge.
//
// The concrete implementation ([NativeAlarmSchedulerImpl]) talks to a
// `MethodChannel` named `"com.alarmx.app.alarmx/alarm_scheduler"`, which is
// handled on the Android side by `MainActivity` and ultimately fires
// `AlarmReceiver` when the alarm goes off.
//
// The scheduler is intentionally minimal at this stage: it only deals with
// one-shot exact alarms. Recurring / snoozed / mission-gated alarms will be
// layered on top in later phases.

abstract class NativeAlarmScheduler {
  /// Schedules a one-shot exact alarm that fires at [triggerAt].
  ///
  /// On Android 12+ (API 31) the user must have granted the
  /// `SCHEDULE_EXACT_ALARM` permission for this to succeed; check
  /// [canScheduleExactAlarms] first and surface a UI prompt if not.
  Future<void> scheduleExactAlarm({
    required int alarmId,
    required DateTime triggerAt,
  });

  /// Cancels a previously scheduled alarm with the given [alarmId].
  /// No-op if no alarm is scheduled with that id.
  Future<void> cancelAlarm({required int alarmId});

  /// Returns `true` if the OS currently allows scheduling exact alarms.
  ///
  /// On Android < 12 this is always `true`; on Android 12+ it reflects
  /// whether the user has granted the `SCHEDULE_EXACT_ALARM` permission.
  Future<bool> canScheduleExactAlarms();
}
