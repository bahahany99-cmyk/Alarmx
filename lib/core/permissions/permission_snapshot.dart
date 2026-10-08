// Permission/system snapshot for the Permission Center (Phase 7).
//
// [PermissionSnapshot] is the single typed view of every capability the
// center reports. It is assembled from the native `getPermissionSnapshot`
// map plus a just-in-time camera status check (never a camera request).
//
// Native map contract (see AlarmSchedulerChannelHandler):
//   sdkInt: Int, notificationsEnabled: Boolean,
//   postNotificationsGranted: Boolean? (null below API 33),
//   ringingChannelEnabled: Boolean,
//   canScheduleExactAlarms: Boolean (true below API 31),
//   fullScreenIntentAllowed: Boolean? (null below API 34),
//   batteryExempt: Boolean, bootReceiverEnabled: Boolean.
// Any missing or mistyped entry degrades its capability to
// [CapabilityState.unknown]; a missing sdkInt degrades every
// version-dependent capability to unknown.

import 'package:alarmx/core/permissions/capability_state.dart';

/// Typed view of every Permission Center capability.
class PermissionSnapshot {
  const PermissionSnapshot({
    required this.notifications,
    required this.exactAlarm,
    required this.fullScreenIntent,
    required this.boot,
    required this.battery,
    required this.camera,
    required this.sdkInt,
  });

  /// Master notification switch + POST_NOTIFICATIONS (33+) + the ringing
  /// channel state combined: any leg off means alarms cannot reliably
  /// present, so the state is [CapabilityState.denied].
  final CapabilityState notifications;

  /// Exact-alarm access; [CapabilityState.notApplicable] below API 31.
  final CapabilityState exactAlarm;

  /// Full-screen-intent allowance; [CapabilityState.notApplicable] below
  /// API 34.
  final CapabilityState fullScreenIntent;

  /// Boot-receiver manifest capability (enabled component).
  final CapabilityState boot;

  /// Battery-optimization exemption (recommended, not mandatory).
  final CapabilityState battery;

  /// Camera runtime state (check-only); relevance is decided by the
  /// reliability calculator from the alarm/mission state.
  final CapabilityState camera;

  /// Android SDK int from the native side (-1 when unreadable).
  final int sdkInt;

  /// All-unknown snapshot for unreadable native replies.
  factory PermissionSnapshot.unknown({required CapabilityState camera}) {
    return PermissionSnapshot(
      notifications: CapabilityState.unknown,
      exactAlarm: CapabilityState.unknown,
      fullScreenIntent: CapabilityState.unknown,
      boot: CapabilityState.unknown,
      battery: CapabilityState.unknown,
      camera: camera,
      sdkInt: -1,
    );
  }

  /// Maps a native snapshot map plus the camera state. Never throws:
  /// every unexpected shape degrades to [CapabilityState.unknown].
  factory PermissionSnapshot.fromSystem({
    required Map<String, Object?> native,
    required CapabilityState camera,
  }) {
    final int sdkInt = _asInt(native['sdkInt']) ?? -1;

    final bool? master = _asBool(native['notificationsEnabled']);
    final bool? postGranted = _asBool(native['postNotificationsGranted']);
    final bool? channel = _asBool(native['ringingChannelEnabled']);
    final CapabilityState notifications;
    if (master == null || channel == null || (sdkInt >= 33 && postGranted == null)) {
      notifications = CapabilityState.unknown;
    } else if (!master || !channel || postGranted == false) {
      notifications = CapabilityState.denied;
    } else {
      notifications = CapabilityState.granted;
    }

    final bool? exact = _asBool(native['canScheduleExactAlarms']);
    final CapabilityState exactAlarm;
    if (sdkInt >= 0 && sdkInt < 31) {
      exactAlarm = CapabilityState.notApplicable;
    } else if (sdkInt < 0 || exact == null) {
      exactAlarm = CapabilityState.unknown;
    } else {
      exactAlarm = exact ? CapabilityState.granted : CapabilityState.denied;
    }

    final bool? fullScreen = _asBool(native['fullScreenIntentAllowed']);
    final CapabilityState fullScreenIntent;
    if (sdkInt >= 0 && sdkInt < 34) {
      fullScreenIntent = CapabilityState.notApplicable;
    } else if (sdkInt < 0 || fullScreen == null) {
      fullScreenIntent = CapabilityState.unknown;
    } else {
      fullScreenIntent =
          fullScreen ? CapabilityState.granted : CapabilityState.denied;
    }

    final bool? bootEnabled = _asBool(native['bootReceiverEnabled']);
    final CapabilityState boot;
    if (bootEnabled == null) {
      boot = CapabilityState.unknown;
    } else {
      // A disabled receiver has no user-facing switch, so it reads as
      // unavailable rather than denied.
      boot = bootEnabled ? CapabilityState.granted : CapabilityState.unavailable;
    }

    final bool? exempt = _asBool(native['batteryExempt']);
    final CapabilityState battery;
    if (exempt == null) {
      battery = CapabilityState.unknown;
    } else {
      battery = exempt ? CapabilityState.granted : CapabilityState.denied;
    }

    return PermissionSnapshot(
      notifications: notifications,
      exactAlarm: exactAlarm,
      fullScreenIntent: fullScreenIntent,
      boot: boot,
      battery: battery,
      camera: camera,
      sdkInt: sdkInt,
    );
  }

  static bool? _asBool(Object? value) => value is bool ? value : null;

  static int? _asInt(Object? value) => value is int ? value : null;
}
