// Tests for photo fingerprinting: dHash mechanics over synthetic images,
// the distance metric, and the encoded-bytes entry point.

import 'dart:typed_data' show Uint8List;
import 'dart:ui' as ui;

import 'package:alarmx/features/missions/photo/photo_fingerprint.dart';
import 'package:flutter_test/flutter_test.dart';

/// Solid 9x8 image in [argb].
Future<ui.Image> solidImage(int argb) async {
  final ui.PictureRecorder recorder = ui.PictureRecorder();
  ui.Canvas(recorder).drawRect(
    const ui.Rect.fromLTWH(0, 0, 9, 8),
    ui.Paint()..color = ui.Color(argb),
  );
  final ui.Image image = await recorder.endRecording().toImage(9, 8);
  return image;
}

/// 9x8 horizontal gray gradient, dark-to-light or the reverse.
Future<ui.Image> gradientImage({required bool leftToRight}) async {
  final ui.PictureRecorder recorder = ui.PictureRecorder();
  final ui.Canvas canvas = ui.Canvas(recorder);
  for (int x = 0; x < 9; x++) {
    final int level = leftToRight ? x * 255 ~/ 8 : (8 - x) * 255 ~/ 8;
    canvas.drawRect(
      ui.Rect.fromLTWH(x.toDouble(), 0, 1, 8),
      ui.Paint()..color = ui.Color.fromARGB(255, level, level, level),
    );
  }
  return recorder.endRecording().toImage(9, 8);
}

void main() {
  group('hashImagePixels', () {
    test('identical images hash identically', () async {
      final int? first = await hashImagePixels(
        await gradientImage(leftToRight: true),
      );
      final int? second = await hashImagePixels(
        await gradientImage(leftToRight: true),
      );
      expect(first, isNotNull);
      expect(first, second);
    });

    test('inverse gradients are maximally distant', () async {
      final int? dark =
          await hashImagePixels(await gradientImage(leftToRight: true));
      final int? light =
          await hashImagePixels(await gradientImage(leftToRight: false));
      expect(dark, isNotNull);
      expect(light, isNotNull);
      expect(dHashDistance(dark!, light!), 64);
    });

    test('flat images carry no signal', () async {
      // Documented dHash property: with no brightness edges every
      // neighbor comparison is false, so any two flat images match.
      // Enrollment rejects these degenerate references (see below).
      final int? black = await hashImagePixels(await solidImage(0xFF000000));
      final int? white = await hashImagePixels(await solidImage(0xFFFFFFFF));
      expect(black, 0);
      expect(dHashDistance(black!, white!), 0);
    });
  });

  group('dHashDistance', () {
    test('counts differing bits', () {
      expect(dHashDistance(0, 0), 0);
      expect(dHashDistance(0, 0xFF), 8);
      expect(dHashDistance(0xAAAAAAAAAAAAAAAA, 0x5555555555555555), 64);
    });

    test('is symmetric', () {
      expect(
        dHashDistance(0x123456789ABCDEF0, 0x0FEDCBA987654321),
        dHashDistance(0x0FEDCBA987654321, 0x123456789ABCDEF0),
      );
    });
  });

  group('isDegenerateFingerprint', () {
    test('flags all-equal bit patterns', () {
      expect(isDegenerateFingerprint(0), isTrue);
      expect(isDegenerateFingerprint(-1), isTrue);
      expect(isDegenerateFingerprint(1), isFalse);
      expect(isDegenerateFingerprint(0x123456789ABCDEF0), isFalse);
    });
  });

  group('computeDHash', () {
    test('round-trips encoded bytes to the same hash', () async {
      final ui.Image image = await gradientImage(leftToRight: true);
      final Uint8List? png = (await image.toByteData(
        format: ui.ImageByteFormat.png,
      ))
          ?.buffer
          .asUint8List();
      expect(png, isNotNull);
      expect(await computeDHash(png!), await hashImagePixels(image));
    });

    test('garbage bytes yield null, never throw', () async {
      expect(await computeDHash(Uint8List(0)), isNull);
      expect(
        await computeDHash(Uint8List.fromList(<int>[1, 2, 3, 4])),
        isNull,
      );
    });
  });
}
