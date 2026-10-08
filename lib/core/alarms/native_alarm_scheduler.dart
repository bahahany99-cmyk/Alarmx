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

import 'alarm_fire_config.dart';

abstract class NativeAlarmScheduler {
  /// Schedules a one-shot exact alarm that fires at [triggerAt].
  ///
  /// On Android 12+ (API 31) the user must have granted the
  /// `SCHEDULE_EXACT_ALARM` permission for this to succeed; check
  /// [canScheduleExactAlarms] first and surface a UI prompt if not.
  ///
  /// When [fireConfig] is provided, the alarm is treated as a real persisted
  /// alarm: the config is frozen into the native PendingIntent and the
  /// schedule is recorded in the native ledger so stale fires can be
  /// dropped. When omitted, the call takes the legacy test path (alarm id
  /// only, exactly the proven Phase 1.2/1.3 behavior).
  Future<void> scheduleExactAlarm({
    required int alarmId,
    required DateTime triggerAt,
    AlarmFireConfig? fireConfig,
  });

  /// Cancels a previously scheduled alarm with the given [alarmId].
  /// No-op if no alarm is scheduled with that id.
  Future<void> cancelAlarm({required int alarmId});

  /// Returns `true` if the OS currently allows scheduling exact alarms.
  ///
  /// On Android < 12 this is always `true`; on Android 12+ it reflects
  /// whether the user has granted the `SCHEDULE_EXACT_ALARM` permission.
  Future<bool> canScheduleExactAlarms();

  /// Returns `true` when the native ringing service is currently ringing
  /// the alarm with [alarmId].
  ///
  /// Read-only: it never starts or stops anything. Reconciliation uses it
  /// to leave an in-progress ring alone (cancelling the native schedule
  /// would stop the ring); the post-fire stop handoff still completes or
  /// chains the alarm after the user stops the ring.
  Future<bool> isRingingAlarm({required int alarmId});
}
