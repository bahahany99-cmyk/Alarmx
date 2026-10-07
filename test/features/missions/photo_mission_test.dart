// Tests for the photo mission: capture outcomes, cancellation, errors,
// and the execution widget (all with a scripted capture source).

import 'package:alarmx/core/l10n/app_strings.dart';
import 'package:alarmx/core/models/models.dart';
import 'package:alarmx/features/missions/mission_config.dart';
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

MissionEntry photoEntry([String label = '']) {
  return MissionEntry(
    id: 1,
    alarmId: 9,
    type: MissionType.photo,
    orderIndex: 0,
    config: PhotoMissionConfig(label),
    required: true,
  );
}

Future<void> pumpPhoto(
  WidgetTester tester,
  MissionEntry entry,
  PhotoCaptureSource source, {
  required VoidCallback onCompleted,
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
