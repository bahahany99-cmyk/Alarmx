// Photo mission logic: capture a photo matching the enrolled reference.
//
// The mission completes when the user captures a photo with the system
// camera app (`image_picker`) whose perceptual fingerprint is close
// enough to the reference enrolled in the editor (see
// `photo_fingerprint.dart`): a mismatch returns to idle with a hint and
// the user retries. The optional config [label] is a display hint only,
// never used for matching. Legacy configs without a reference
// fingerprint keep the original capture-to-complete behavior so old
// alarms never brick.
//
// No camera permission is requested by us: the system camera app holds
// its own. Capture lives behind [PhotoCaptureSource] and fingerprinting
// behind [FingerprintSource] so the controller is unit-testable and CI
// never touches a camera. The captured path is session evidence only and
// is never persisted.

import 'dart:io' show File;

import 'package:alarmx/features/missions/photo/photo_fingerprint.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

/// Outcome of one photo capture attempt.
sealed class PhotoCaptureOutcome {
  const PhotoCaptureOutcome();
}

/// A usable photo was captured at [path].
class PhotoCaptured extends PhotoCaptureOutcome {
  const PhotoCaptured(this.path);

  final String path;
}

/// The user left the camera without capturing.
class PhotoCaptureCancelled extends PhotoCaptureOutcome {
  const PhotoCaptureCancelled();
}

/// Capture failed (no camera app, IO error, ...).
class PhotoCaptureFailed extends PhotoCaptureOutcome {
  const PhotoCaptureFailed();
}

/// Captures one photo with the system camera. Never throws: every
/// failure mode maps to an outcome.
abstract class PhotoCaptureSource {
  Future<PhotoCaptureOutcome> capturePhoto();
}

/// [PhotoCaptureSource] backed by `image_picker` (system camera app).
class ImagePickerPhotoSource implements PhotoCaptureSource {
  ImagePickerPhotoSource({ImagePicker? picker})
      : _picker = picker ?? ImagePicker();

  final ImagePicker _picker;

  @override
  Future<PhotoCaptureOutcome> capturePhoto() async {
    final String? path;
    try {
      final XFile? file = await _picker.pickImage(source: ImageSource.camera);
      path = file?.path;
    } catch (_) {
      return const PhotoCaptureFailed();
    }
    if (path == null || path.isEmpty) {
      return const PhotoCaptureCancelled();
    }
    try {
      final File captured = File(path);
      if (!await captured.exists() || await captured.length() == 0) {
        return const PhotoCaptureFailed();
      }
    } catch (_) {
      return const PhotoCaptureFailed();
    }
    return PhotoCaptured(path);
  }
}

/// Execution phase of one photo mission.
enum PhotoPhase {
  /// Ready to capture (also the state after a cancellation or mismatch).
  idle,

  /// System camera open, awaiting the capture result.
  capturing,

  /// Capture received; comparing its fingerprint to the reference.
  verifying,

  /// Photo verified; the mission is complete.
  done,

  /// Capture failed; retrying re-enters [capturing].
  error,
}

/// Owns one photo mission's progress; see the file docs.
///
/// [capture] opens the system camera; concurrent calls collapse into the
/// in-flight capture/verification and calls after [isDone] are no-ops.
/// Cancellation returns to [PhotoPhase.idle] with [cancelledHint] raised;
/// a non-matching capture returns to idle with [mismatchHint] raised so
/// the UI can prompt another attempt.
class PhotoMissionController extends ChangeNotifier {
  PhotoMissionController({
    required this.label,
    required PhotoCaptureSource captureSource,
    this.expectedFingerprint,
    FingerprintSource? fingerprintSource,
  })  : _source = captureSource,
        _fingerprints = fingerprintSource ?? const FileFingerprintSource();

  /// Optional display hint from the mission config (what to photograph).
  final String label;

  /// Enrolled reference fingerprint, or null for legacy configs (any
  /// capture completes).
  final int? expectedFingerprint;

  final PhotoCaptureSource _source;
  final FingerprintSource _fingerprints;
  PhotoPhase _phase = PhotoPhase.idle;
  bool _cancelledHint = false;
  bool _mismatchHint = false;
  String? _capturedPath;

  PhotoPhase get phase => _phase;

  bool get cancelledHint => _cancelledHint;

  bool get mismatchHint => _mismatchHint;

  bool get isDone => _phase == PhotoPhase.done;

  /// Session evidence (the captured file path); never persisted.
  String? get capturedPath => _capturedPath;

  Future<void> capture() async {
    if (_phase == PhotoPhase.capturing ||
        _phase == PhotoPhase.verifying ||
        _phase == PhotoPhase.done) {
      return;
    }
    _phase = PhotoPhase.capturing;
    _cancelledHint = false;
    _mismatchHint = false;
    notifyListeners();
    final PhotoCaptureOutcome outcome;
    try {
      outcome = await _source.capturePhoto();
    } catch (_) {
      _phase = PhotoPhase.error;
      notifyListeners();
      return;
    }
    switch (outcome) {
      case PhotoCaptured(:final path):
        _capturedPath = path;
        final int? expected = expectedFingerprint;
        if (expected == null) {
          // Legacy config: capture completion is the whole mission.
          _phase = PhotoPhase.done;
          break;
        }
        _phase = PhotoPhase.verifying;
        notifyListeners();
        final int? actual;
        try {
          actual = await _fingerprints.fingerprintOf(path);
        } catch (_) {
          _phase = PhotoPhase.idle;
          _mismatchHint = true;
          break;
        }
        if (actual != null &&
            dHashDistance(expected, actual) <= kPhotoMatchThreshold) {
          _phase = PhotoPhase.done;
        } else {
          _phase = PhotoPhase.idle;
          _mismatchHint = true;
        }
      case PhotoCaptureCancelled():
        _phase = PhotoPhase.idle;
        _cancelledHint = true;
      case PhotoCaptureFailed():
        _phase = PhotoPhase.error;
    }
    notifyListeners();
  }
}
