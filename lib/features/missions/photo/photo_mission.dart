// Photo mission logic (Phase 4): capture-to-complete.
//
// The mission completes when the user captures a photo with the system
// camera app (`image_picker`): the returned file must exist and be
// non-empty. This validates capture completion — not image similarity;
// local computer-vision matching is explicitly deferred to the later
// V1.1/V2 enhancement, and the optional config [label] is a display hint
// only, never used for matching.
//
// No camera permission is requested by us: the system camera app holds
// its own. Capture lives behind [PhotoCaptureSource] so the controller
// is unit-testable and CI never touches a camera. The captured path is
// session evidence only and is never persisted.

import 'dart:io' show File;

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
  /// Ready to capture (also the state after a cancellation).
  idle,

  /// System camera open, awaiting the capture result.
  capturing,

  /// Photo captured; the mission is complete.
  done,

  /// Capture failed; retrying re-enters [capturing].
  error,
}

/// Owns one photo mission's progress; see the file docs.
///
/// [capture] opens the system camera; concurrent calls collapse into the
/// in-flight capture and calls after [isDone] are no-ops. Cancellation
/// returns to [PhotoPhase.idle] with [cancelledHint] raised so the UI can
/// prompt another attempt.
class PhotoMissionController extends ChangeNotifier {
  PhotoMissionController({
    required this.label,
    required PhotoCaptureSource captureSource,
  }) : _source = captureSource;

  /// Optional display hint from the mission config (what to photograph).
  final String label;

  final PhotoCaptureSource _source;
  PhotoPhase _phase = PhotoPhase.idle;
  bool _cancelledHint = false;
  String? _capturedPath;

  PhotoPhase get phase => _phase;

  bool get cancelledHint => _cancelledHint;

  bool get isDone => _phase == PhotoPhase.done;

  /// Session evidence (the captured file path); never persisted.
  String? get capturedPath => _capturedPath;

  Future<void> capture() async {
    if (_phase == PhotoPhase.capturing || _phase == PhotoPhase.done) {
      return;
    }
    _phase = PhotoPhase.capturing;
    _cancelledHint = false;
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
        _phase = PhotoPhase.done;
      case PhotoCaptureCancelled():
        _phase = PhotoPhase.idle;
        _cancelledHint = true;
      case PhotoCaptureFailed():
        _phase = PhotoPhase.error;
    }
    notifyListeners();
  }
}
