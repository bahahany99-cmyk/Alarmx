// Tests for the sequence mission: deterministic dealing/direction,
// exact-order tapping with wrong-tap resets, and the execution widget
// (seeded random, solution learned from a test-side controller with the
// same seed).

import 'dart:math' show Random;

import 'package:alarmx/core/l10n/app_strings.dart';
import 'package:alarmx/core/models/models.dart';
import 'package:alarmx/features/missions/mission_config.dart';
import 'package:alarmx/features/missions/sequence/sequence_mission.dart';
import 'package:alarmx/features/missions/sequence/sequence_mission_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/test_doubles.dart';

const SequenceMissionConfig easyConfig =
    SequenceMissionConfig(difficulty: SequenceDifficulty.easy);

MissionEntry sequenceEntry(SequenceMissionConfig config) {
  return MissionEntry(
    id: 1,
    alarmId: 9,
    type: MissionType.sequence,
    orderIndex: 0,
    config: config,
    required: true,
  );
}

Future<void> pumpSequence(
  WidgetTester tester,
  MissionEntry entry, {
  required VoidCallback onCompleted,
  Random? random,
}) async {
  // Tall viewport: square grid cells make even small boards taller than
  // the default 800x600 surface; offscreen tiles are not tappable.
  tester.view.physicalSize = const Size(800, 4000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale(AppLanguage.english),
      supportedLocales: testLocales,
      localizationsDelegates: testDelegates,
      home: Scaffold(
        body: SingleChildScrollView(
          child: SequenceMissionWidget(
            entry: entry,
            onCompleted: onCompleted,
            random: random,
          ),
        ),
      ),
    ),
  );
  await pumpSettle(tester);
}

void main() {
  group('SequenceMissionController', () {
    test('deals distinct in-range tiles per difficulty', () {
      for (final SequenceDifficulty difficulty in SequenceDifficulty.values) {
        final SequenceMissionController controller =
            SequenceMissionController(
          config: SequenceMissionConfig(difficulty: difficulty),
          random: Random(7),
        );
        addTearDown(controller.dispose);
        expect(controller.tiles, hasLength(difficulty.tileCount));
        expect(controller.tiles.toSet(), hasLength(difficulty.tileCount));
        for (final int tile in controller.tiles) {
          expect(tile >= 1 && tile <= 99, isTrue);
        }
      }
    });

    test('both directions occur across seeds', () {
      final Set<SequenceDirection> seen = <SequenceDirection>{};
      for (int seed = 0; seed < 20; seed++) {
        final SequenceMissionController controller =
            SequenceMissionController(
          config: easyConfig,
          random: Random(seed),
        );
        addTearDown(controller.dispose);
        seen.add(controller.direction);
      }
      expect(seen, SequenceDirection.values.toSet());
    });

    test('exact-order taps complete; wrong tap resets', () {
      final SequenceMissionController controller = SequenceMissionController(
        config: easyConfig,
        random: Random(9),
      );
      addTearDown(controller.dispose);
      final List<int> ordered = List<int>.of(controller.tiles)..sort();
      final List<int> solution =
          controller.direction == SequenceDirection.ascending
              ? ordered
              : ordered.reversed.toList();
      int displayIndexOf(int value) => controller.tiles.indexOf(value);

      controller.tap(displayIndexOf(solution[0]));
      expect(controller.progress, 1);
      expect(controller.lastAttemptWrong, isFalse);
      // A later solution value out of order is wrong.
      controller.tap(displayIndexOf(solution[2]));
      expect(controller.progress, 0);
      expect(controller.lastAttemptWrong, isTrue);
      expect(controller.isDone, isFalse);
      for (final int value in solution) {
        controller.tap(displayIndexOf(value));
      }
      expect(controller.isDone, isTrue);
    });

    test('found, out-of-range and post-done taps are no-ops', () {
      final SequenceMissionController controller = SequenceMissionController(
        config: easyConfig,
        random: Random(9),
      );
      addTearDown(controller.dispose);
      controller.tap(-1);
      controller.tap(99);
      expect(controller.progress, 0);
      final List<int> ordered = List<int>.of(controller.tiles)..sort();
      final List<int> solution =
          controller.direction == SequenceDirection.ascending
              ? ordered
              : ordered.reversed.toList();
      final int first = controller.tiles.indexOf(solution[0]);
      controller.tap(first);
      controller.tap(first);
      expect(controller.progress, 1);
      for (final int value in solution.skip(1)) {
        controller.tap(controller.tiles.indexOf(value));
      }
      expect(controller.isDone, isTrue);
      controller.tap(first);
      expect(controller.progress, controller.total);
    });
  });

  group('SequenceMissionWidget', () {
    final AppStrings en = AppStrings.forCode(AppLanguage.english);

    testWidgets('renders the prompt, progress and tiles',
        (WidgetTester tester) async {
      final SequenceMissionController learned = SequenceMissionController(
        config: easyConfig,
        random: Random(4),
      );
      addTearDown(learned.dispose);
      await pumpSequence(
        tester,
        sequenceEntry(easyConfig),
        onCompleted: () {},
        random: Random(4),
      );
      expect(
        find.text(
          learned.direction == SequenceDirection.ascending
              ? en.sequencePromptAsc
              : en.sequencePromptDesc,
        ),
        findsOneWidget,
      );
      expect(find.byKey(const Key('sequence_progress')), findsOneWidget);
      expect(find.byKey(const Key('sequence_tile_0')), findsOneWidget);
      expect(find.byKey(const Key('sequence_tile_4')), findsOneWidget);
      expect(find.byKey(const Key('sequence_tile_5')), findsNothing);
    });

    testWidgets('tapping in order completes exactly once',
        (WidgetTester tester) async {
      int completions = 0;
      final SequenceMissionController learned = SequenceMissionController(
        config: easyConfig,
        random: Random(4),
      );
      addTearDown(learned.dispose);
      final List<int> ordered = List<int>.of(learned.tiles)..sort();
      final List<int> solution =
          learned.direction == SequenceDirection.ascending
              ? ordered
              : ordered.reversed.toList();
      await pumpSequence(
        tester,
        sequenceEntry(easyConfig),
        onCompleted: () {
          completions++;
        },
        random: Random(4),
      );
      for (final int value in solution) {
        final int display = learned.tiles.indexOf(value);
        await tester.tap(find.byKey(Key('sequence_tile_$display')));
        await tester.pump();
      }
      expect(completions, 1);
      expect(find.text(en.missionCompleted), findsOneWidget);
    });

    testWidgets('wrong tap shows the hint and resets progress',
        (WidgetTester tester) async {
      final SequenceMissionController learned = SequenceMissionController(
        config: easyConfig,
        random: Random(4),
      );
      addTearDown(learned.dispose);
      final List<int> ordered = List<int>.of(learned.tiles)..sort();
      final List<int> solution =
          learned.direction == SequenceDirection.ascending
              ? ordered
              : ordered.reversed.toList();
      await pumpSequence(
        tester,
        sequenceEntry(easyConfig),
        onCompleted: () {},
        random: Random(4),
      );
      // Correct first, then a later solution value out of order.
      await tester.tap(
        find.byKey(Key('sequence_tile_${learned.tiles.indexOf(solution[0])}')),
      );
      await tester.pump();
      await tester.tap(
        find.byKey(Key('sequence_tile_${learned.tiles.indexOf(solution[3])}')),
      );
      await tester.pump();
      expect(find.text(en.sequenceWrong), findsOneWidget);
      expect(find.textContaining('0 / 5'), findsOneWidget);
    });

    testWidgets('mismatched config renders the invalid state, never crashes',
        (WidgetTester tester) async {
      await pumpSequence(
        tester,
        const MissionEntry(
          id: 1,
          alarmId: 9,
          type: MissionType.sequence,
          orderIndex: 0,
          config: TypingMissionConfig('x'),
          required: true,
        ),
        onCompleted: () {},
      );
      expect(find.text(en.ringingSkippedInvalid), findsOneWidget);
    });
  });
}
