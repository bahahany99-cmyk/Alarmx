// Photo reference fingerprinting: perceptual-hash matching, fully local.
//
// The photo mission enrolls a reference fingerprint (a 64-bit dHash of a
// reference capture) and completes only when a later capture is close
// enough to it. Everything runs on-device with zero dependencies:
// decode/normalize via `dart:ui`, a pure difference hash, and a Hamming
// comparison.
//
// dHash recap: shrink to 9x8 grayscale (aspect is deliberately NOT
// preserved — the stretch is part of the standard recipe), then record,
// for each of the 64 left/right neighbor pairs, whether the left pixel
// is brighter than the right one. Small lighting/cropping differences
// flip few bits; a different scene flips many. [kPhotoMatchThreshold] is
// deliberately lenient: a false reject strands a half-awake user, while
// a false accept only ends one mission.

import 'dart:io' show File;
import 'dart:typed_data' show Uint8List;
import 'dart:ui' as ui;

/// Maximum Hamming distance between reference and capture fingerprints
/// that still counts as a match (out of 64 bits).
const int kPhotoMatchThreshold = 10;

/// Normalized fingerprint width/height (9x8 yields exactly 64 neighbor
/// comparisons).
const int kFingerprintWidth = 9;
const int kFingerprintHeight = 8;

/// Computes the 64-bit dHash of encoded image [bytes].
///
/// Decodes through `dart:ui` (any platform-supported format), redraws to
/// exactly 9x8, and hashes. Returns null when the bytes do not decode.
/// Never throws: every failure maps to null.
Future<int?> computeDHash(Uint8List bytes) async {
  try {
    final ui.Codec codec = await ui.instantiateImageCodec(bytes);
    final ui.FrameInfo frame = await codec.getNextFrame();
    final ui.Image decoded = frame.image;
    final ui.PictureRecorder recorder = ui.PictureRecorder();
    ui.Canvas(recorder).drawImageRect(
      decoded,
      ui.Rect.fromLTWH(
        0,
        0,
        decoded.width.toDouble(),
        decoded.height.toDouble(),
      ),
      ui.Rect.fromLTWH(
        0,
        0,
        kFingerprintWidth.toDouble(),
        kFingerprintHeight.toDouble(),
      ),
      ui.Paint(),
    );
    final ui.Image normalized = await recorder
        .endRecording()
        .toImage(kFingerprintWidth, kFingerprintHeight);
    decoded.dispose();
    codec.dispose();
    final int? hash = await hashImagePixels(normalized);
    normalized.dispose();
    return hash;
  } catch (_) {
    return null;
  }
}

/// Pure dHash over an already-decoded [image].
///
/// Reads RGBA bytes, converts to grayscale, and hashes left/right
/// neighbor comparisons row by row (a 9x8 image yields exactly 64
/// bits). Separated from [computeDHash] so tests can feed synthetic
/// images without encoding round-trips. Never throws: unreadable input
/// maps to null.
Future<int?> hashImagePixels(ui.Image image) async {
  try {
    final Uint8List? rgba =
        (await image.toByteData(format: ui.ImageByteFormat.rawRgba))
            ?.buffer
            .asUint8List();
    if (rgba == null) {
      return null;
    }
    final int width = image.width;
    final int height = image.height;
    if (width < 2 || rgba.length < width * height * 4) {
      return null;
    }
    int hash = 0;
    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width - 1; x++) {
        final int left = _gray(rgba, (y * width + x) * 4);
        final int right = _gray(rgba, (y * width + x + 1) * 4);
        hash = (hash << 1) | (left > right ? 1 : 0);
      }
    }
    return hash;
  } catch (_) {
    return null;
  }
}

/// ITU-R BT.601 luma of the RGBA pixel starting at [offset].
int _gray(Uint8List rgba, int offset) {
  return (rgba[offset] * 299 +
          rgba[offset + 1] * 587 +
          rgba[offset + 2] * 114) ~/
      1000;
}

/// Whether [hash] carries no signal (every neighbor comparison agreed,
/// i.e. all bits equal). Flat scenes (blank walls, dark rooms) hash like
/// this and would match any other flat capture, so enrollment rejects
/// them; see the editor dialog.
bool isDegenerateFingerprint(int hash) => hash == 0 || hash == -1;

/// Hamming distance between two fingerprints: how many of the 64 bits
/// differ. Pure and total.
int dHashDistance(int a, int b) {
  int differing = a ^ b;
  int count = 0;
  while (differing != 0) {
    differing &= differing - 1;
    count++;
  }
  return count;
}

/// Computes fingerprints for captured photo files.
abstract class FingerprintSource {
  /// Fingerprint of the photo at [path], or null when it cannot be
  /// read/decoded. Never throws.
  Future<int?> fingerprintOf(String path);
}

/// [FingerprintSource] over real files on disk.
class FileFingerprintSource implements FingerprintSource {
  const FileFingerprintSource();

  @override
  Future<int?> fingerprintOf(String path) async {
    try {
      final Uint8List bytes = await File(path).readAsBytes();
      if (bytes.isEmpty) {
        return null;
      }
      final int? hash = await computeDHash(bytes);
      return hash;
    } catch (_) {
      return null;
    }
  }
}
