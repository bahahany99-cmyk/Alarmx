// Camera permission gate (Phase 4): just-in-time requests.
//
// Camera missions (QR, barcode, photo capture) request access ONLY when the
// mission actually starts executing — never at app startup, never on Home,
// never when creating/editing an alarm. The request lives behind
// [CameraPermissionGate] so mission controllers are unit-testable with
// scripted outcomes and CI never touches platform permission APIs.

import 'package:permission_handler/permission_handler.dart';

/// Outcome of a camera permission request.
enum CameraPermissionOutcome {
  /// Camera may be used.
  granted,

  /// Usable after another request (system may still prompt).
  denied,

  /// System will no longer prompt; the user must grant via app settings.
  permanentlyDenied,
}

/// Requests camera access for a starting camera mission.
abstract class CameraPermissionGate {
  /// Requests camera access, returning the outcome. Never throws:
  /// platform errors degrade to [CameraPermissionOutcome.denied].
  Future<CameraPermissionOutcome> requestCamera();

  /// Checks the current camera status WITHOUT requesting it, for the
  /// Permission Center: viewing capabilities must never trigger a system
  /// prompt. Never throws: platform errors degrade to
  /// [CameraPermissionOutcome.denied].
  Future<CameraPermissionOutcome> checkCameraStatus();

  /// Opens the app settings page (permanently-denied recovery). Best
  /// effort; never throws.
  Future<void> openSettings();
}

/// [CameraPermissionGate] backed by `permission_handler`.
class PermissionHandlerCameraGate implements CameraPermissionGate {
  const PermissionHandlerCameraGate();

  @override
  Future<CameraPermissionOutcome> requestCamera() async {
    final PermissionStatus status;
    try {
      status = await Permission.camera.request();
    } catch (_) {
      return CameraPermissionOutcome.denied;
    }
    if (status.isGranted) {
      return CameraPermissionOutcome.granted;
    }
    if (status.isPermanentlyDenied) {
      return CameraPermissionOutcome.permanentlyDenied;
    }
    return CameraPermissionOutcome.denied;
  }

  @override
  Future<void> openSettings() async {
    try {
      await openAppSettings();
    } catch (_) {
      // Best effort: there is nothing else to offer when settings cannot
      // be opened; the mission UI keeps its retry state.
    }
  }
}
