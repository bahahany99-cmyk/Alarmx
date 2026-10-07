// Tests for the shake mission: detector thresholds/debounce, controller
// progress/completion/disposal over a fake sensor stream, and the widget.

import 'dart:async' show StreamController;

import 'package:alarmx/core/l10n/app_strings.dart';
import 'package:alarmx/core/models/models.dart';
import 'package:alarmx/features/missions/mission_config.dart';
import 'package:alarmx/features/missions/shake/shake_mission.dart';
import 'package:alarmx/features/missions/shake/shake_mission_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/test_doubles.dart';

/// Scripted sensor stream for tests.
class FakeShakeSource implements ShakeSensorSource {
  final StreamController<AccelSample> events =
      StreamController<AccelSample>.broadcast();

  @override
  Stream<AccelSample> get samples => events.stream;

  void emit(double magnitude) {
    events.add(AccelSample(magnitude, 0, 0));
  }

  void fail() {
    events.addError(StateError('no sensor'));
  }

  Future<void> close() => events.close();
}

/// Deterministic clock for debounce tests.
class FakeClock {
  FakeClock(this.now);
  DateTime now;
  DateTime call() => now;
  void advance(Duration d) {
    now = now.add(d);
  }
}

MissionEntry shakeEntry(int count) {
  return MissionEntry(
    id: 1,
    alarmId: 9,
    type: MissionType.shake,
    orderIndex: 0,
    config: ShakeMissionConfig(count),
    required: true,
  );
}

Future<void> pumpShake(
  WidgetTester tester,
  MissionEntry entry,
  FakeShakeSource source, {
  required VoidCallback onCompleted,
  ShakeDetector? detector,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale(AppLanguage.english),
      supportedLocales: testLocales,
      localizationsDelegates: testDelegates,
      home: Scaffold(
        body: SingleChildScrollView(
          child: ShakeMissionWidget(
            entry: entry,
            onCompleted: onCompleted,
            source: source,
            detector: detector,
          ),
        ),
      ),
    ),
  );
  await pumpSettle(tester);
}

void main() {
  group('ShakeDetector', () {
    test('below-threshold samples never count', () {
      final ShakeDetector detector = ShakeDetector();
      expect(detector.feed(const AccelSample(0, 0, 9.8)), isFalse);
      expect(detector.feed(const AccelSample(14.9, 0, 0)), isFalse);
      expect(detector.count, 0);
    });

    test('threshold sample counts', () {
      final ShakeDetector detector = ShakeDetector();
      expect(detector.feed(const AccelSample(15.0, 0, 0)), isTrue);
      expect(detector.count, 1);
    });

    test('debounce suppresses one physical shake counted twice', () {
      final FakeClock clock = FakeClock(DateTime(2026, 1, 1));
      final ShakeDetector detector = ShakeDetector(clock: clock.call);
      expect(detector.feed(const AccelSample(20, 0, 0)), isTrue);
      clock.advance(const Duration(milliseconds: 100));
      expect(detector.feed(const AccelSample(25, 0, 0)), isFalse);
      clock.advance(const Duration(milliseconds: 400));
      expect(detector.feed(const AccelSample(25, 0, 0)), isTrue);
      expect(detector.count, 2);
    });

    test('reset clears count and debounce memory', () {
      final FakeClock clock = FakeClock(DateTime(2026, 1, 1));
      final ShakeDetector detector = ShakeDetector(clock: clock.call);
      detector.feed(const AccelSample(20, 0, 0));
      detector.reset();
      expect(detector.count, 0);
      expect(detector.feed(const AccelSample(20, 0, 0)), isTrue);
    });
  });

  group('ShakeMissionController', () {
    test('counts shakes and completes at the required count', () async {
      final FakeShakeSource source = FakeShakeSource();
      addTearDown(source.close);
      final ShakeMissionController controller = ShakeMissionController(
        config: const ShakeMissionConfig(2),
        source: source,
        detector: ShakeDetector(debounce: Duration.zero),
      );
      addTearDown(controller.dispose);
      controller.start();
      expect(controller.progress, 0);
      expect(controller.isDone, isFalse);
      source.emit(9.8);
      await Future<void>.delayed(Duration.zero);
      expect(controller.progress, 0);
      source.emit(20);
      await Future<void>.delayed(Duration.zero);
      expect(controller.progress, 1);
      source.emit(20);
      await Future<void>.delayed(Duration.zero);
      expect(controller.progress, 2);
      expect(controller.isDone, isTrue);
      // Events after completion are ignored.
      source.emit(20);
      await Future<void>.delayed(Duration.zero);
      expect(controller.progress, 2);
    });

    test('sensor errors raise sensorFailed and stay incomplete', () async {
      final FakeShakeSource source = FakeShakeSource();
      addTearDown(source.close);
      final ShakeMissionController controller = ShakeMissionController(
        config: const ShakeMissionConfig(1),
        source: source,
      );
      addTearDown(controller.dispose);
      controller.start();
      source.fail();
      await Future<void>.delayed(Duration.zero);
      expect(controller.sensorFailed, isTrue);
      expect(controller.isDone, isFalse);
      // Retry re-subscribes and can still complete.
      controller.start();
      expect(controller.sensorFailed, isFalse);
      source.emit(20);
      await Future<void>.delayed(Duration.zero);
      expect(controller.isDone, isTrue);
    });

    test('start is idempotent and stop/dispose end monitoring', () async {
      final FakeShakeSource source = FakeShakeSource();
      addTearDown(source.close);
      final ShakeMissionController controller = ShakeMissionController(
        config: const ShakeMissionConfig(5),
        source: source,
        detector: ShakeDetector(debounce: Duration.zero),
      );
      controller.start();
      controller.start();
      source.emit(20);
      await Future<void>.delayed(Duration.zero);
      // A duplicate subscription would have counted twice.
      expect(controller.progress, 1);
      await controller.stop();
      source.emit(20);
      await Future<void>.delayed(Duration.zero);
      expect(controller.progress, 1);
      controller.dispose();
    });
  });

  group('ShakeMissionWidget', () {
    final AppStrings en = AppStrings.forCode(AppLanguage.english);

    testWidgets('renders instruction and zero progress',
        (WidgetTester tester) async {
      final FakeShakeSource source = FakeShakeSource();
      addTearDown(source.close);
      await pumpShake(tester, shakeEntry(3), source, onCompleted: () {});
      expect(find.text(en.shakeInstruction), findsOneWidget);
      expect(find.text('0 / 3'), findsOneWidget);
    });

    testWidgets('progress updates and completes exactly once',
        (WidgetTester tester) async {
      final FakeShakeSource source = FakeShakeSource();
      addTearDown(source.close);
      int completions = 0;
      await pumpShake(
        tester,
        shakeEntry(2),
        source,
        onCompleted: () {
          completions++;
        },
      );
      source.emit(20);
      await pumpSettle(tester);
      expect(find.text('1 / 2'), findsOneWidget);
      expect(completions, 0);
      // A second sample within the 500ms debounce must not count: the
      // fake-async pumps above advanced fake time, so advance it past the
      // debounce explicitly for the completing shake.
      await tester.pump(const Duration(milliseconds: 600));
      source.emit(20);
      await pumpSettle(tester);
      expect(find.text(en.missionCompleted), findsOneWidget);
      expect(completions, 1);
    });

    testWidgets('sensor failure shows the error state with a retry',
        (WidgetTester tester) async {
      final FakeShakeSource source = FakeShakeSource();
      addTearDown(source.close);
      int completions = 0;
      await pumpShake(
        tester,
        shakeEntry(1),
        source,
        onCompleted: () {
          completions++;
        },
      );
      source.fail();
      await pumpSettle(tester);
      expect(find.text(en.sensorUnavailable), findsOneWidget);
      expect(find.byKey(const Key('shake_retry_button')), findsOneWidget);
      expect(completions, 0);
      await tester.tap(find.byKey(const Key('shake_retry_button')));
      await pumpSettle(tester);
      source.emit(20);
      await pumpSettle(tester);
      expect(completions, 1);
    });

    testWidgets('mismatched config renders the invalid state, never crashes',
        (WidgetTester tester) async {
      final FakeShakeSource source = FakeShakeSource();
      addTearDown(source.close);
      await pumpShake(
        tester,
        const MissionEntry(
          id: 1,
          alarmId: 9,
          type: MissionType.shake,
          orderIndex: 0,
          config: TypingMissionConfig('x'),
          required: true,
        ),
        source,
        onCompleted: () {},
      );
      expect(find.text(en.ringingSkippedInvalid), findsOneWidget);
    });
  });
}
