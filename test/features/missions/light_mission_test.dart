// Tests for the light mission: catch sampling/threshold/fallback, glow
// dot movement/snapping, and both execution widgets (scripted gate).
//
// The catch widget samples on a widget-owned periodic timer, so these
// widget tests pump manually (never settle: the timer never settles).

import 'package:alarmx/core/l10n/app_strings.dart';
import 'package:alarmx/core/models/models.dart';
import 'package:alarmx/features/missions/light/light_mission.dart';
import 'package:alarmx/features/missions/light/light_mission_widget.dart';
import 'package:alarmx/features/missions/light/light_sensor_gate.dart';
import 'package:alarmx/features/missions/mission_config.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/test_doubles.dart';

/// Scripted sensor gate for tests.
class FakeLightGate implements LightSensorGate {
  FakeLightGate(this.readings);

  final List<double?> readings;
  int calls = 0;

  @override
  Future<double?> readLux() async {
    calls++;
    if (readings.isEmpty) {
      return null;
    }
    return readings.removeAt(0);
  }
}

MissionEntry lightEntry(LightMode mode) {
  return MissionEntry(
    id: 1,
    alarmId: 9,
    type: MissionType.light,
    orderIndex: 0,
    config: LightMissionConfig(mode: mode),
    required: true,
  );
}

Future<void> pumpLight(
  WidgetTester tester,
  MissionEntry entry,
  LightSensorGate gate, {
  required VoidCallback onCompleted,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale(AppLanguage.english),
      supportedLocales: testLocales,
      localizationsDelegates: testDelegates,
      home: Scaffold(
        body: SingleChildScrollView(
          child: LightMissionWidget(
            entry: entry,
            onCompleted: onCompleted,
            gate: gate,
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  group('LightCatchController', () {
    test('below-target samples update lux without completing', () async {
      final LightCatchController controller = LightCatchController(
        gate: FakeLightGate(<double?>[100.0, 200.0]),
      );
      addTearDown(controller.dispose);
      await controller.sample();
      expect(controller.lux, 100.0);
      expect(controller.isDone, isFalse);
      expect(controller.needsFallback, isFalse);
      expect(controller.progress, closeTo(0.25, 0.001));
      await controller.sample();
      expect(controller.lux, 200.0);
      expect(controller.isDone, isFalse);
    });

    test('target sample completes', () async {
      final LightCatchController controller = LightCatchController(
        gate: FakeLightGate(<double?>[kLightCatchTargetLux]),
      );
      addTearDown(controller.dispose);
      await controller.sample();
      expect(controller.isDone, isTrue);
      expect(controller.progress, 1.0);
    });

    test('null reading latches the fallback and stops sampling', () async {
      final FakeLightGate gate = FakeLightGate(<double?>[]);
      final LightCatchController controller =
          LightCatchController(gate: gate);
      addTearDown(controller.dispose);
      await controller.sample();
      expect(controller.needsFallback, isTrue);
      expect(controller.isDone, isFalse);
      await controller.sample();
      expect(gate.calls, 1);
    });

    test('samples after done are no-ops', () async {
      final FakeLightGate gate =
          FakeLightGate(<double?>[1000.0, 1000.0]);
      final LightCatchController controller =
          LightCatchController(gate: gate);
      addTearDown(controller.dispose);
      await controller.sample();
      await controller.sample();
      expect(gate.calls, 1);
      expect(controller.isDone, isTrue);
    });
  });

  group('GlowDotController', () {
    test('moves clamp to the unit square', () {
      final GlowDotController controller = GlowDotController();
      addTearDown(controller.dispose);
      controller.move(const Offset(-0.5, 1.5));
      expect(controller.dot, const Offset(0.0, 1.0));
      expect(controller.isDone, isFalse);
    });

    test('entering the snap radius completes and locks the socket', () {
      final GlowDotController controller = GlowDotController(
        socket: const Offset(0.5, 0.5),
        snapRadius: 0.1,
      );
      addTearDown(controller.dispose);
      controller.move(const Offset(0.0, 0.0));
      expect(controller.isDone, isFalse);
      controller.move(const Offset(0.55, 0.55));
      expect(controller.isDone, isTrue);
      expect(controller.dot, const Offset(0.5, 0.5));
      controller.move(const Offset(0.0, 0.0));
      expect(controller.dot, const Offset(0.5, 0.5));
    });
  });

  group('LightMissionWidget', () {
    final AppStrings en = AppStrings.forCode(AppLanguage.english);

    testWidgets('catch shows live lux and completes at target',
        (WidgetTester tester) async {
      int completions = 0;
      await pumpLight(
        tester,
        lightEntry(LightMode.lightCatch),
        FakeLightGate(<double?>[100.0, 500.0]),
        onCompleted: () {
          completions++;
        },
      );
      await tester.pump();
      expect(find.textContaining('100 / 400'), findsOneWidget);
      expect(completions, 0);
      await tester.pump(kLightCatchPollInterval);
      await tester.pump();
      expect(completions, 1);
      expect(find.text(en.missionCompleted), findsOneWidget);
    });

    testWidgets('no sensor offers glow dot for this execution',
        (WidgetTester tester) async {
      int completions = 0;
      await pumpLight(
        tester,
        lightEntry(LightMode.lightCatch),
        FakeLightGate(<double?>[]),
        onCompleted: () {
          completions++;
        },
      );
      await tester.pump();
      expect(find.text(en.lightNoSensor), findsOneWidget);
      expect(completions, 0);
      await tester.tap(find.byKey(const Key('light_glow_instead')));
      await tester.pump();
      expect(find.byKey(const Key('glow_canvas')), findsOneWidget);
      expect(find.text(en.lightGlowInstruction), findsOneWidget);
    });

    testWidgets('glow drag into the ring completes',
        (WidgetTester tester) async {
      int completions = 0;
      await pumpLight(
        tester,
        lightEntry(LightMode.glowDot),
        FakeLightGate(<double?>[]),
        onCompleted: () {
          completions++;
        },
      );
      final Offset topLeft =
          tester.getTopLeft(find.byKey(const Key('glow_canvas')));
      final Size size =
          tester.getSize(find.byKey(const Key('glow_canvas')));
      final Offset start = topLeft +
          Offset(0.2 * size.width, 0.75 * size.height);
      final Offset end = topLeft +
          Offset(0.8 * size.width, 0.25 * size.height);
      await tester.dragFrom(start, end - start);
      await tester.pump();
      expect(completions, 1);
      expect(find.text(en.missionCompleted), findsOneWidget);
    });

    testWidgets('mismatched config renders the invalid state, never crashes',
        (WidgetTester tester) async {
      await pumpLight(
        tester,
        const MissionEntry(
          id: 1,
          alarmId: 9,
          type: MissionType.light,
          orderIndex: 0,
          config: TypingMissionConfig('x'),
          required: true,
        ),
        FakeLightGate(<double?>[]),
        onCompleted: () {},
      );
      expect(find.text(en.ringingSkippedInvalid), findsOneWidget);
    });
  });
}
