// Tests for the photo mission: capture outcomes, cancellation, errors,
// reference matching, and the execution widget (all with scripted
// capture/fingerprint sources).

import 'dart:async' show Completer;

import 'package:alarmx/core/l10n/app_strings.dart';
import 'package:alarmx/core/models/models.dart';
import 'package:alarmx/features/missions/mission_config.dart';
import 'package:alarmx/features/missions/photo/photo_fingerprint.dart';
import 'package:alarmx/features/missions/photo/photo_mission.dart';
import 'package:alarmx/features/missions/photo/photo_mission_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/test_doubles.dart';

/// Scripted capture source for tests.
class FakePhotoSource implements PhotoCaptureSource {
  FakePhotoSource(this.outcomes);

  final List<PhotoCaptureOutcome> outcomes;
  int calls = 0;

  @override
  Future<PhotoCaptureOutcome> capturePhoto() async {
    calls++;
    if (outcomes.isEmpty) {
      return const PhotoCaptureCancelled();
    }
    return outcomes.removeAt(0);
  }
}

class ThrowingPhotoSource implements PhotoCaptureSource {
  @override
  Future<PhotoCaptureOutcome> capturePhoto() {
    throw StateError('boom');
  }
}

/// Scripted fingerprint source for tests.
class FakeFingerprintSource implements FingerprintSource {
  FakeFingerprintSource(this.results);

  final List<int?> results;
  int calls = 0;

  @override
  Future<int?> fingerprintOf(String path) async {
    calls++;
    if (results.isEmpty) {
      return null;
    }
    return results.removeAt(0);
  }
}

/// Fingerprint source blocked on [gate] for verifying-phase tests.
class GatedFingerprintSource implements FingerprintSource {
  GatedFingerprintSource(this.gate, this.result);

  final Completer<void> gate;
  final int? result;

  @override
  Future<int?> fingerprintOf(String path) async {
    await gate.future;
    return result;
  }
}

MissionEntry photoEntry([String label = '', int? fingerprint]) {
  return MissionEntry(
    id: 1,
    alarmId: 9,
    type: MissionType.photo,
    orderIndex: 0,
    config: PhotoMissionConfig(label, fingerprint),
    required: true,
  );
}

Future<void> pumpPhoto(
  WidgetTester tester,
  MissionEntry entry,
  PhotoCaptureSource source, {
  required VoidCallback onCompleted,
  FingerprintSource? fingerprints,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale(AppLanguage.english),
      supportedLocales: testLocales,
      localizationsDelegates: testDelegates,
      home: Scaffold(
        body: SingleChildScrollView(
          child: PhotoMissionWidget(
            entry: entry,
            onCompleted: onCompleted,
            captureSource: source,
            fingerprintSource: fingerprints,
          ),
        ),
      ),
    ),
  );
  await pumpSettle(tester);
}

void main() {
  group('PhotoMissionController', () {
    test('captured photo completes with session evidence', () async {
      final PhotoMissionController controller = PhotoMissionController(
        label: '',
        captureSource:
            FakePhotoSource(<PhotoCaptureOutcome>[const PhotoCaptured('/p.jpg')]),
      );
      addTearDown(controller.dispose);
      await controller.capture();
      expect(controller.isDone, isTrue);
      expect(controller.capturedPath, '/p.jpg');
      expect(controller.cancelledHint, isFalse);
    });

    test('concurrent captures collapse into one', () async {
      final FakePhotoSource source = FakePhotoSource(
        <PhotoCaptureOutcome>[const PhotoCaptured('/p.jpg')],
      );
      final PhotoMissionController controller = PhotoMissionController(
        label: '',
        captureSource: source,
      );
      addTearDown(controller.dispose);
      await Future.wait(<Future<void>>[
        controller.capture(),
        controller.capture(),
      ]);
      expect(source.calls, 1);
      expect(controller.isDone, isTrue);
    });

    test('cancellation returns to idle with a hint, retry works', () async {
      final PhotoMissionController controller = PhotoMissionController(
        label: '',
        captureSource: FakePhotoSource(<PhotoCaptureOutcome>[
          const PhotoCaptureCancelled(),
          const PhotoCaptured('/p.jpg'),
        ]),
      );
      addTearDown(controller.dispose);
      await controller.capture();
      expect(controller.phase, PhotoPhase.idle);
      expect(controller.cancelledHint, isTrue);
      expect(controller.isDone, isFalse);
      await controller.capture();
      expect(controller.isDone, isTrue);
      expect(controller.cancelledHint, isFalse);
    });

    test('failure enters error, retry recovers', () async {
      final PhotoMissionController controller = PhotoMissionController(
        label: '',
        captureSource: FakePhotoSource(<PhotoCaptureOutcome>[
          const PhotoCaptureFailed(),
          const PhotoCaptured('/p.jpg'),
        ]),
      );
      addTearDown(controller.dispose);
      await controller.capture();
      expect(controller.phase, PhotoPhase.error);
      await controller.capture();
      expect(controller.isDone, isTrue);
    });

    test('throwing source degrades to error, never throws', () async {
      final PhotoMissionController controller = PhotoMissionController(
        label: '',
        captureSource: ThrowingPhotoSource(),
      );
      addTearDown(controller.dispose);
      await controller.capture();
      expect(controller.phase, PhotoPhase.error);
    });

    test('legacy config without a reference completes on capture', () async {
      final FakePhotoSource source = FakePhotoSource(
        <PhotoCaptureOutcome>[const PhotoCaptured('/shot.jpg')],
      );
      final FakeFingerprintSource fingerprints =
          FakeFingerprintSource(<int?>[0x1234]);
      final PhotoMissionController controller = PhotoMissionController(
        label: '',
        captureSource: source,
        fingerprintSource: fingerprints,
      );
      await controller.capture();
      expect(controller.isDone, isTrue);
      expect(fingerprints.calls, 0);
    });

    test('close-enough capture completes', () async {
      const int reference = 0x123456789ABCDEF0;
      final FakePhotoSource source = FakePhotoSource(
        <PhotoCaptureOutcome>[const PhotoCaptured('/shot.jpg')],
      );
      final PhotoMissionController controller = PhotoMissionController(
        label: '',
        captureSource: source,
        expectedFingerprint: reference,
        // Two flipped bits: well within the threshold.
        fingerprintSource: FakeFingerprintSource(<int?>[reference ^ 0x3]),
      );
      await controller.capture();
      expect(controller.phase, PhotoPhase.done);
      expect(controller.isDone, isTrue);
    });

    test('distant capture mismatches and retries', () async {
      const int reference = 0x123456789ABCDEF0;
      final FakePhotoSource source = FakePhotoSource(
        <PhotoCaptureOutcome>[
          const PhotoCaptured('/wrong.jpg'),
          const PhotoCaptured('/right.jpg'),
        ],
      );
      final PhotoMissionController controller = PhotoMissionController(
        label: '',
        captureSource: source,
        expectedFingerprint: reference,
        fingerprintSource: FakeFingerprintSource(
          <int?>[reference ^ 0x0FEDCBA987654321, reference],
        ),
      );
      await controller.capture();
      expect(controller.isDone, isFalse);
      expect(controller.phase, PhotoPhase.idle);
      expect(controller.mismatchHint, isTrue);
      await controller.capture();
      expect(controller.isDone, isTrue);
      expect(controller.mismatchHint, isFalse);
    });

    test('unreadable capture mismatches instead of completing', () async {
      final FakePhotoSource source = FakePhotoSource(
        <PhotoCaptureOutcome>[const PhotoCaptured('/shot.jpg')],
      );
      final PhotoMissionController controller = PhotoMissionController(
        label: '',
        captureSource: source,
        expectedFingerprint: 0x1234,
        fingerprintSource: FakeFingerprintSource(<int?>[null]),
      );
      await controller.capture();
      expect(controller.isDone, isFalse);
      expect(controller.mismatchHint, isTrue);
    });

    test('concurrent captures collapse during verification', () async {
      final Completer<void> gate = Completer<void>();
      final FakePhotoSource source = FakePhotoSource(
        <PhotoCaptureOutcome>[const PhotoCaptured('/shot.jpg')],
      );
      final PhotoMissionController controller = PhotoMissionController(
        label: '',
        captureSource: source,
        expectedFingerprint: 0x1234,
        fingerprintSource: GatedFingerprintSource(gate, 0x1234),
      );
      final Future<void> first = controller.capture();
      await Future<void>.delayed(Duration.zero);
      expect(controller.phase, PhotoPhase.verifying);
      await controller.capture();
      gate.complete();
      await first;
      expect(source.calls, 1);
      expect(controller.isDone, isTrue);
    });

    test('capture after done is a no-op', () async {
      final FakePhotoSource source = FakePhotoSource(
        <PhotoCaptureOutcome>[const PhotoCaptured('/p.jpg')],
      );
      final PhotoMissionController controller = PhotoMissionController(
        label: '',
        captureSource: source,
      );
      addTearDown(controller.dispose);
      await controller.capture();
      await controller.capture();
      expect(source.calls, 1);
    });
  });

  group('PhotoMissionWidget', () {
    final AppStrings en = AppStrings.forCode(AppLanguage.english);

    testWidgets('renders instruction, label and take button',
        (WidgetTester tester) async {
      await pumpPhoto(
        tester,
        photoEntry('bathroom sink'),
        FakePhotoSource(<PhotoCaptureOutcome>[]),
        onCompleted: () {},
      );
      expect(find.text(en.photoInstruction), findsOneWidget);
      expect(find.text('bathroom sink'), findsOneWidget);
      expect(find.byKey(const Key('photo_take_button')), findsOneWidget);
    });

    testWidgets('capture completes exactly once',
        (WidgetTester tester) async {
      int completions = 0;
      await pumpPhoto(
        tester,
        photoEntry(),
        FakePhotoSource(<PhotoCaptureOutcome>[
          const PhotoCaptured('/p.jpg'),
        ]),
        onCompleted: () {
          completions++;
        },
      );
      await tester.tap(find.byKey(const Key('photo_take_button')));
      await pumpSettle(tester);
      expect(completions, 1);
      expect(find.text(en.missionCompleted), findsOneWidget);
    });

    testWidgets('cancellation shows the hint and allows retry',
        (WidgetTester tester) async {
      int completions = 0;
      await pumpPhoto(
        tester,
        photoEntry(),
        FakePhotoSource(<PhotoCaptureOutcome>[
          const PhotoCaptureCancelled(),
          const PhotoCaptured('/p.jpg'),
        ]),
        onCompleted: () {
          completions++;
        },
      );
      await tester.tap(find.byKey(const Key('photo_take_button')));
      await pumpSettle(tester);
      expect(find.text(en.photoCancelled), findsOneWidget);
      expect(completions, 0);
      await tester.tap(find.byKey(const Key('photo_take_button')));
      await pumpSettle(tester);
      expect(completions, 1);
    });

    testWidgets('failure shows the error state with a retry',
        (WidgetTester tester) async {
      await pumpPhoto(
        tester,
        photoEntry(),
        FakePhotoSource(<PhotoCaptureOutcome>[
          const PhotoCaptureFailed(),
          const PhotoCaptured('/p.jpg'),
        ]),
        onCompleted: () {},
      );
      await tester.tap(find.byKey(const Key('photo_take_button')));
      await pumpSettle(tester);
      expect(find.text(en.photoError), findsOneWidget);
      await tester.tap(find.byKey(const Key('photo_retry_button')));
      await pumpSettle(tester);
      expect(find.text(en.missionCompleted), findsOneWidget);
    });

    testWidgets('mismatch shows the hint and allows retry',
        (WidgetTester tester) async {
      const int reference = 0x123456789ABCDEF0;
      int completions = 0;
      await pumpPhoto(
        tester,
        photoEntry('sink', reference),
        FakePhotoSource(<PhotoCaptureOutcome>[
          const PhotoCaptured('/wrong.jpg'),
          const PhotoCaptured('/right.jpg'),
        ]),
        onCompleted: () {
          completions++;
        },
        fingerprints: FakeFingerprintSource(
          <int?>[reference ^ 0x0FEDCBA987654321, reference],
        ),
      );
      await tester.tap(find.byKey(const Key('photo_take_button')));
      await pumpSettle(tester);
      expect(find.text(en.photoMismatch), findsOneWidget);
      expect(completions, 0);
      await tester.tap(find.byKey(const Key('photo_take_button')));
      await pumpSettle(tester);
      expect(completions, 1);
      expect(find.text(en.missionCompleted), findsOneWidget);
    });

    testWidgets('verification shows progress until the verdict',
        (WidgetTester tester) async {
      final Completer<void> gate = Completer<void>();
      int completions = 0;
      await pumpPhoto(
        tester,
        photoEntry('', 0x1234),
        FakePhotoSource(<PhotoCaptureOutcome>[
          const PhotoCaptured('/p.jpg'),
        ]),
        onCompleted: () {
          completions++;
        },
        fingerprints: GatedFingerprintSource(gate, 0x1234),
      );
      await tester.tap(find.byKey(const Key('photo_take_button')));
      await tester.pump();
      await tester.pump();
      expect(find.text(en.photoVerifying), findsOneWidget);
      gate.complete();
      await pumpSettle(tester);
      expect(completions, 1);
      expect(find.text(en.missionCompleted), findsOneWidget);
    });

    testWidgets('mismatched config renders the invalid state, never crashes',
        (WidgetTester tester) async {
      await pumpPhoto(
        tester,
        const MissionEntry(
          id: 1,
          alarmId: 9,
          type: MissionType.photo,
          orderIndex: 0,
          config: TypingMissionConfig('x'),
          required: true,
        ),
        FakePhotoSource(<PhotoCaptureOutcome>[]),
        onCompleted: () {},
      );
      expect(find.text(en.ringingSkippedInvalid), findsOneWidget);
    });
  });
}
