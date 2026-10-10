// Notification permission gate: runtime POST_NOTIFICATIONS requests.
//
// Only the notifications onboarding step uses this. POST_NOTIFICATIONS is
// a runtime permission on API 33+: the system shows an in-app dialog and
// the outcome is known the moment it dismisses. Below API 33 the concept
// does not exist (the master switch + channel state decide), and the
// special permissions (exact alarm, full-screen intent, battery) are
// Settings-only — those go through the settings bridge, never here.
//
// The request lives behind [NotificationPermissionGate] (mirroring the
// camera gate) so the onboarding flow is unit-testable with scripted
// outcomes and CI never touches platform permission APIs.

import 'package:permission_handler/permission_handler.dart';

/// Outcome of a notification permission request.
enum NotificationPermissionOutcome {
  /// Notifications may be used.
  granted,

  /// Usable after another request (system may still prompt).
  denied,

  /// System will no longer prompt; the user must grant via app settings.
  permanentlyDenied,
}

/// Requests POST_NOTIFICATIONS for the onboarding notifications step.
abstract class NotificationPermissionGate {
  /// Requests notification access via the system runtime dialog,
  /// returning the outcome. Never throws: platform errors degrade to
  /// [NotificationPermissionOutcome.denied].
  Future<NotificationPermissionOutcome> requestNotifications();
}

/// [NotificationPermissionGate] backed by `permission_handler`.
class PermissionHandlerNotificationGate implements NotificationPermissionGate {
  const PermissionHandlerNotificationGate();

  @override
  Future<NotificationPermissionOutcome> requestNotifications() async {
    final PermissionStatus status;
    try {
      status = await Permission.notification.request();
    } catch (_) {
      return NotificationPermissionOutcome.denied;
    }
    if (status.isGranted) {
      return NotificationPermissionOutcome.granted;
    }
    if (status.isPermanentlyDenied) {
      return NotificationPermissionOutcome.permanentlyDenied;
    }
    return NotificationPermissionOutcome.denied;
  }
}
