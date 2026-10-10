// Tests for the memory mission: deterministic dealing, flip/match rules,
// and the execution widget (seeded random, layout learned from a
// test-side controller with the same seed).

import 'dart:math' show Random;

import 'package:alarmx/core/l10n/app_strings.dart';
import 'package:alarmx/core/models/models.dart';
import 'package:alarmx/features/missions/memory/memory_mission.dart';
import 'package:alarmx/features/missions/memory/memory_mission_widget.dart';
import 'package:alarmx/features/missions/mission_config.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/test_doubles.dart';

const MemoryMissionConfig easyConfig =
    MemoryMissionConfig(difficulty: MemoryDifficulty.easy);

MemoryEntry memoryEntry(MemoryMissionConfig config) {
  return MissionEntry(
    id: 1,
    alarmId: 9,
    type: MissionType.memory,
    orderIndex: 0,
    config: config,
    required: true,
  );
}

Future<void> pumpMemory(
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
          child: MemoryMissionWidget(
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
  group('MemoryMissionController', () {
    test('deals the configured card count with each face twice', () {
      for (final MemoryDifficulty difficulty in MemoryDifficulty.values) {
        final MemoryMissionController controller = MemoryMissionController(
          config: MemoryMissionConfig(difficulty: difficulty),
          random: Random(7),
        );
        addTearDown(controller.dispose);
        expect(controller.cards, hasLength(difficulty.cardCount));
        expect(controller.totalPairs, difficulty.cardCount ~/ 2);
        final Map<String, int> faceCounts = <String, int>{};
        for (final MemoryCard card in controller.cards) {
          faceCounts[card.face] = (faceCounts[card.face] ?? 0) + 1;
        }
        expect(faceCounts.values.toSet(), <int>{2});
      }
    });

    test('same seed deals the same layout', () {
      List<String> faces(int seed) {
        final MemoryMissionController controller = MemoryMissionController(
          config: easyConfig,
          random: Random(seed),
        );
        addTearDown(controller.dispose);
        return <String>[
          for (final MemoryCard card in controller.cards) card.face,
        ];
      }

      expect(faces(42), faces(42));
    });

    test('matching pair stays revealed and counts one move', () {
      final MemoryMissionController controller = MemoryMissionController(
        config: easyConfig,
        random: Random(3),
      );
      addTearDown(controller.dispose);
      final int first = controller.cards.indexWhere(
        (MemoryCard card) => card.pairId == 0,
      );
      final int second = controller.cards.lastIndexWhere(
        (MemoryCard card) => card.pairId == 0,
      );
      controller.flip(first);
      expect(controller.isRevealed(first), isTrue);
      expect(controller.moves, 0);
      controller.flip(second);
      expect(controller.isMatched(first), isTrue);
      expect(controller.isMatched(second), isTrue);
      expect(controller.moves, 1);
      expect(controller.matchedPairs, 1);
    });

    test('third tap clears a pending mismatch first', () {
      final MemoryMissionController controller = MemoryMissionController(
        config: easyConfig,
        random: Random(3),
      );
      addTearDown(controller.dispose);
      final int first = controller.cards.indexWhere(
        (MemoryCard card) => card.pairId == 0,
      );
      final int other = controller.cards.indexWhere(
        (MemoryCard card) => card.pairId == 1,
      );
      controller.flip(first);
      controller.flip(other);
      expect(controller.matchedPairs, 0);
      expect(controller.moves, 1);
      final int third = controller.cards.indexWhere(
        (MemoryCard card) => card.pairId == 2,
      );
      controller.flip(third);
      expect(controller.isRevealed(first), isFalse);
      expect(controller.isRevealed(other), isFalse);
      expect(controller.isRevealed(third), isTrue);
    });

    test('matched, revealed and out-of-range flips are no-ops', () {
      final MemoryMissionController controller = MemoryMissionController(
        config: easyConfig,
        random: Random(3),
      );
      addTearDown(controller.dispose);
      controller.flip(-1);
      controller.flip(99);
      expect(controller.moves, 0);
      controller.flip(0);
      controller.flip(0);
      expect(controller.moves, 0);
      final int mate = controller.cards.lastIndexWhere(
        (MemoryCard card) => card.pairId == controller.cards[0].pairId,
      );
      controller.flip(mate);
      expect(controller.moves, 1);
      controller.flip(0);
      controller.flip(mate);
      expect(controller.moves, 1);
    });

    test('completes when every pair matches', () {
      final MemoryMissionController controller = MemoryMissionController(
        config: easyConfig,
        random: Random(11),
      );
      addTearDown(controller.dispose);
      for (int pair = 0; pair < controller.totalPairs; pair++) {
        final List<int> spots = <int>[];
        for (int i = 0; i < controller.cards.length; i++) {
          if (controller.cards[i].pairId == pair) {
            spots.add(i);
          }
        }
        controller.flip(spots[0]);
        controller.flip(spots[1]);
      }
      expect(controller.isDone, isTrue);
      expect(controller.matchedPairs, controller.totalPairs);
    });
  });

  group('MemoryMissionWidget', () {
    final AppStrings en = AppStrings.forCode(AppLanguage.english);

    testWidgets('renders instruction, progress and the card grid',
        (WidgetTester tester) async {
      await pumpMemory(
        tester,
        memoryEntry(easyConfig),
        onCompleted: () {},
        random: Random(5),
      );
      expect(find.text(en.memoryInstruction), findsOneWidget);
      expect(find.byKey(const Key('memory_progress')), findsOneWidget);
      expect(find.byKey(const Key('memory_card_0')), findsOneWidget);
      expect(find.byKey(const Key('memory_card_11')), findsOneWidget);
      expect(find.byKey(const Key('memory_card_12')), findsNothing);
    });

    testWidgets('matching pair advances progress; full grid completes',
        (WidgetTester tester) async {
      int completions = 0;
      // The widget shuffles from Random(5): learn the layout from a
      // test-side controller with the same seed.
      final MemoryMissionController learned = MemoryMissionController(
        config: easyConfig,
        random: Random(5),
      );
      addTearDown(learned.dispose);
      await pumpMemory(
        tester,
        memoryEntry(easyConfig),
        onCompleted: () {
          completions++;
        },
        random: Random(5),
      );
      Future<void> tapPair(int pair) async {
        final List<int> spots = <int>[];
        for (int i = 0; i < learned.cards.length; i++) {
          if (learned.cards[i].pairId == pair) {
            spots.add(i);
          }
        }
        await tester.tap(find.byKey(Key('memory_card_${spots[0]}')));
        await tester.pump();
        await tester.tap(find.byKey(Key('memory_card_${spots[1]}')));
        await tester.pump();
      }

      await tapPair(0);
      expect(find.textContaining('1 / 6'), findsOneWidget);
      for (int pair = 1; pair < learned.totalPairs; pair++) {
        await tapPair(pair);
      }
      expect(completions, 1);
      expect(find.text(en.missionCompleted), findsOneWidget);
    });

    testWidgets('hard deals 64 cards', (WidgetTester tester) async {
      await pumpMemory(
        tester,
        memoryEntry(
          const MemoryMissionConfig(difficulty: MemoryDifficulty.hard),
        ),
        onCompleted: () {},
        random: Random(5),
      );
      expect(find.byKey(const Key('memory_card_63')), findsOneWidget);
      expect(find.textContaining('0 / 32'), findsOneWidget);
    });

    testWidgets('mismatched config renders the invalid state, never crashes',
        (WidgetTester tester) async {
      await pumpMemory(
        tester,
        const MissionEntry(
          id: 1,
          alarmId: 9,
          type: MissionType.memory,
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
