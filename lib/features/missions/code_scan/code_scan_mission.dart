// Shared QR/barcode scan mission logic (Phase 4).
//
// Both missions compare a scanned code value against the configured
// expected value ([checkScannedValue]: exact after trimming surrounding
// whitespace on both sides) and share the [CodeScanMissionController]
// phase machine: permission request -> scanning -> done, with recoverable
// denied/permanently-denied/error states. Only the instruction text and
// the scanner's format filter differ per type.
//
// The controller never imports the scanner package: the live camera view
// is injected by the widget, so every phase is unit-testable with a fake
// permission gate and scripted detections, and CI never touches a camera.

import 'package:flutter/foundation.dart';

import '../permissions/camera_permission.dart';

/// Checks a scanned code against the configured expected value.
///
/// Exact after trimming both sides. A `null`/empty scan — or an empty
/// expected value, which validation forbids — never succeeds.
bool checkScannedValue(String expectedValue, String? scanned) {
  final String expected = expectedValue.trim();
  if (expected.isEmpty || scanned == null) {
    return false;
  }
  return scanned.trim() == expected;
}

/// Execution phase of one scan mission.
enum CodeScanPhase {
  /// Not started (also the state after a user cancellation).
  idle,

  /// Awaiting the just-in-time camera permission request.
  requestingPermission,

  /// Permission denied; another request may still prompt.
  permissionDenied,

  /// Permission permanently denied; only app settings can grant.
  permissionPermanentlyDenied,

  /// Camera running, awaiting a matching scan.
  scanning,

  /// Expected value scanned; the scanner view must be released.
  done,

  /// Scanner failure; retrying re-enters [requestingPermission].
  error,
}

/// Owns one scan mission's progress; see the file docs.
///
/// [start] requests camera access and enters [CodeScanPhase.scanning] when
/// granted. [onCodeDetected] completes on the expected value and raises
/// [wrongAttempt] otherwise (the mission keeps scanning). Completion and
/// cancellation are idempotent; [scanNonce] changes on every entry into
/// [CodeScanPhase.scanning] so the widget rebuilds a fresh scanner view.
class CodeScanMissionController extends ChangeNotifier {
  CodeScanMissionController({
    required this.expectedValue,
    required CameraPermissionGate permissionGate,
  }) : _permissionGate = permissionGate;

  final String expectedValue;
  final CameraPermissionGate _permissionGate;
  CodeScanPhase _phase = CodeScanPhase.idle;
  bool _wrongAttempt = false;
  int _scanNonce = 0;
  bool _startInFlight = false;

  CodeScanPhase get phase => _phase;

  bool get wrongAttempt => _wrongAttempt;

  int get scanNonce => _scanNonce;

  bool get isDone => _phase == CodeScanPhase.done;

  /// Requests camera access and starts scanning when granted. Concurrent
  /// calls collapse into the in-flight request; calls after [isDone] are
  /// no-ops.
  Future<void> start() async {
    if (_phase == CodeScanPhase.done || _startInFlight) {
      return;
    }
    _startInFlight = true;
    _phase = CodeScanPhase.requestingPermission;
    _wrongAttempt = false;
    notifyListeners();
    final CameraPermissionOutcome outcome;
    try {
      outcome = await _permissionGate.requestCamera();
    } catch (_) {
      _phase = CodeScanPhase.permissionDenied;
      _startInFlight = false;
      notifyListeners();
      return;
    }
    _startInFlight = false;
    switch (outcome) {
      case CameraPermissionOutcome.granted:
        _scanNonce++;
        _phase = CodeScanPhase.scanning;
      case CameraPermissionOutcome.denied:
        _phase = CodeScanPhase.permissionDenied;
      case CameraPermissionOutcome.permanentlyDenied:
        _phase = CodeScanPhase.permissionPermanentlyDenied;
    }
    notifyListeners();
  }

  /// Reports one detected code value (`null` when the scan read nothing).
  /// Only the expected value completes; anything else raises
  /// [wrongAttempt] and keeps scanning. No-op unless [phase] is scanning.
  void onCodeDetected(String? rawValue) {
    if (_phase != CodeScanPhase.scanning) {
      return;
    }
    if (checkScannedValue(expectedValue, rawValue)) {
      _phase = CodeScanPhase.done;
      _wrongAttempt = false;
    } else {
      _wrongAttempt = true;
    }
    notifyListeners();
  }

  /// Reports a scanner failure. No-op unless [phase] is scanning.
  void onScannerError() {
    if (_phase != CodeScanPhase.scanning) {
      return;
    }
    _phase = CodeScanPhase.error;
    notifyListeners();
  }

  /// Cancels back to [CodeScanPhase.idle] (the widget releases the scanner
  /// view). Safe from any phase; no-op once done.
  void cancelScan() {
    if (_phase == CodeScanPhase.done) {
      return;
    }
    _phase = CodeScanPhase.idle;
    _wrongAttempt = false;
    notifyListeners();
  }

  /// Opens app settings (permanently-denied recovery). Best effort.
  Future<void> openSettings() => _permissionGate.openSettings();
}
