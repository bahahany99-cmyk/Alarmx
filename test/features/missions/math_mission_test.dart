// Tests for the math mission: deterministic generation, difficulty
// shapes, answer checking, controller progress, and the widget.

import 'dart:math' show Random;

import 'package:alarmx/core/l10n/app_strings.dart';
import 'package:alarmx/core/models/models.dart';
import 'package:alarmx/features/missions/math/math_mission.dart';
import 'package:alarmx/features/missions/math/math_mission_widget.dart';
import 'package:alarmx/features/missions/mission_config.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/test_doubles.dart';

const MathMissionConfig easy3 = MathMissionConfig(
  questionCount: 3,
  difficulty: MathDifficulty.easy,
);

MissionEntry mathEntry(MathMissionConfig config) {
  return MissionEntry(
    id: 1,
    alarmId: 9,
    type: MissionType.math,
    orderIndex: 0,
    config: config,
    required: true,
  );
}

List<MathQuestion> generateWithSeed(MathMissionConfig config, int seed) {
  return MathQuestionGenerator(Random(seed)).generate(config);
}

Future<void> pumpMath(
  WidgetTester tester,
  MissionEntry entry, {
  required VoidCallback onCompleted,
  int seed = 11,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale(AppLanguage.english),
      supportedLocales: testLocales,
      localizationsDelegates: testDelegates,
      home: Scaffold(
        body: SingleChildScrollView(
          child: MathMissionWidget(
            entry: entry,
            onCompleted: onCompleted,
            random: Random(seed),
          ),
        ),
      ),
    ),
  );
  await pumpSettle(tester);
}

void main() {
  group('MathQuestion', () {
    test('answers and display for every operator', () {
      const MathQuestion add =
          MathQuestion(a: 3, b: 4, operator: MathOperator.add);
      expect(add.answer, 7);
      expect(add.display(), '3 + 4 = ?');
      const MathQuestion sub =
          MathQuestion(a: 9, b: 4, operator: MathOperator.subtract);
      expect(sub.answer, 5);
      expect(sub.display(), '9 - 4 = ?');
      const MathQuestion mul =
          MathQuestion(a: 6, b: 7, operator: MathOperator.multiply);
      expect(mul.answer, 42);
      expect(mul.display(), '6 × 7 = ?');
      const MathQuestion div =
          MathQuestion(a: 20, b: 5, operator: MathOperator.divide);
      expect(div.answer, 4);
      expect(div.display(), '20 ÷ 5 = ?');
    });
  });

  group('MathQuestionGenerator', () {
    test('same seed yields the same questions', () {
      final List<String> first = generateWithSeed(easy3, 7)
          .map((MathQuestion q) => q.display())
          .toList();
      final List<String> second = generateWithSeed(easy3, 7)
          .map((MathQuestion q) => q.display())
          .toList();
      expect(first, hasLength(3));
      expect(second, first);
    });

    test('question count is honored', () {
      for (final int count in <int>[1, 3, 5, 10, 20]) {
        final MathMissionConfig config = MathMissionConfig(
          questionCount: count,
          difficulty: MathDifficulty.medium,
        );
        expect(generateWithSeed(config, 1), hasLength(count));
      }
    });

    void checkRanges(MathDifficulty difficulty) {
      for (int seed = 0; seed < 40; seed++) {
        final MathMissionConfig config = MathMissionConfig(
          questionCount: 10,
          difficulty: difficulty,
        );
        for (final MathQuestion q in generateWithSeed(config, seed)) {
          switch (difficulty) {
            case MathDifficulty.easy:
              expect(q.a >= 1 && q.a <= 20, isTrue);
              expect(q.b >= 1 && q.b <= 20, isTrue);
              expect(
                q.operator == MathOperator.add ||
                    q.operator == MathOperator.subtract,
                isTrue,
              );
            case MathDifficulty.medium:
              if (q.operator == MathOperator.multiply) {
                expect(q.a >= 2 && q.a <= 12, isTrue);
                expect(q.b >= 2 && q.b <= 12, isTrue);
              } else {
                expect(q.a >= 1 && q.a <= 100, isTrue);
                expect(q.b >= 1 && q.b <= 100, isTrue);
              }
            case MathDifficulty.hard:
              if (q.operator == MathOperator.multiply) {
                expect(q.a >= 2 && q.a <= 15, isTrue);
                expect(q.b >= 2 && q.b <= 15, isTrue);
              } else if (q.operator == MathOperator.divide) {
                expect(q.b >= 2 && q.b <= 12, isTrue);
                expect(q.a % q.b, 0);
              } else {
                expect(q.a >= 1 && q.a <= 200, isTrue);
                expect(q.b >= 1 && q.b <= 200, isTrue);
              }
          }
          if (q.operator == MathOperator.subtract) {
            expect(q.a >= q.b, isTrue);
            expect(q.answer >= 0, isTrue);
          }
        }
      }
    }

    test('easy shapes stay in range', () {
      checkRanges(MathDifficulty.easy);
    });

    test('medium shapes stay in range', () {
      checkRanges(MathDifficulty.medium);
    });

    test('hard shapes stay in range with exact division', () {
      checkRanges(MathDifficulty.hard);
    });
  });

  group('checkMathAnswer', () {
    const MathQuestion q =
        MathQuestion(a: 6, b: 7, operator: MathOperator.multiply);

    test('correct answers succeed', () {
      expect(checkMathAnswer(q, '42'), isTrue);
      expect(checkMathAnswer(q, '  42 '), isTrue);
    });

    test('wrong, empty and non-numeric answers fail', () {
      expect(checkMathAnswer(q, '41'), isFalse);
      expect(checkMathAnswer(q, ''), isFalse);
      expect(checkMathAnswer(q, '   '), isFalse);
      expect(checkMathAnswer(q, 'abc'), isFalse);
      expect(checkMathAnswer(q, '4.2'), isFalse);
      expect(checkMathAnswer(q, '-42'), isFalse);
    });
  });

  group('MathMissionController', () {
    MathMissionController controllerOf(MathMissionConfig config, int seed) {
      return MathMissionController(config: config, random: Random(seed));
    }

    test('wrong answer keeps the question and raises the flag', () {
      final MathMissionController controller = controllerOf(easy3, 3);
      addTearDown(controller.dispose);
      expect(controller.index, 0);
      expect(controller.total, 3);
      expect(controller.submit('not a number'), isFalse);
      expect(controller.lastAttemptFailed, isTrue);
      expect(controller.index, 0);
      expect(controller.isDone, isFalse);
    });

    test('correct answers advance and complete at the end', () {
      const int seed = 5;
      final MathMissionController controller = controllerOf(easy3, seed);
      addTearDown(controller.dispose);
      final List<MathQuestion> expected = generateWithSeed(easy3, seed);
      expect(controller.submit('${expected[0].answer}'), isFalse);
      expect(controller.lastAttemptFailed, isFalse);
      expect(controller.index, 1);
      expect(controller.submit('${expected[1].answer}'), isFalse);
      expect(controller.index, 2);
      expect(controller.submit('${expected[2].answer}'), isTrue);
      expect(controller.isDone, isTrue);
      expect(controller.submit('anything'), isTrue);
    });
  });

  group('MathMissionWidget', () {
    final AppStrings en = AppStrings.forCode(AppLanguage.english);

    testWidgets('renders progress, question, field and button',
        (WidgetTester tester) async {
      await pumpMath(tester, mathEntry(easy3), onCompleted: () {});
      expect(find.textContaining('${en.missionProgress} 1 / 3'), findsOneWidget);
      expect(find.byKey(const Key('math_answer_field')), findsOneWidget);
      expect(find.byKey(const Key('math_solve_button')), findsOneWidget);
    });

    testWidgets('wrong answer shows failure and keeps the question',
        (WidgetTester tester) async {
      int completions = 0;
      await pumpMath(
        tester,
        mathEntry(easy3),
        onCompleted: () {
          completions++;
        },
      );
      await tester.enterText(
        find.byKey(const Key('math_answer_field')),
        'wrong',
      );
      await tester.tap(find.byKey(const Key('math_solve_button')));
      await pumpSettle(tester);
      expect(find.text(en.missionIncorrect), findsOneWidget);
      expect(find.textContaining('${en.missionProgress} 1 / 3'), findsOneWidget);
      expect(completions, 0);
    });

    testWidgets('solving every question completes exactly once',
        (WidgetTester tester) async {
      const int seed = 11;
      int completions = 0;
      await pumpMath(
        tester,
        mathEntry(easy3),
        onCompleted: () {
          completions++;
        },
        seed: seed,
      );
      final List<MathQuestion> expected = generateWithSeed(easy3, seed);
      for (int i = 0; i < expected.length; i++) {
        await tester.enterText(
          find.byKey(const Key('math_answer_field')),
          '${expected[i].answer}',
        );
        await tester.tap(find.byKey(const Key('math_solve_button')));
        await pumpSettle(tester);
      }
      expect(completions, 1);
      expect(find.text(en.missionCompleted), findsOneWidget);
      await tester.tap(
        find.byKey(const Key('math_solve_button')),
        warnIfMissed: false,
      );
      await pumpSettle(tester);
      expect(completions, 1);
    });

    testWidgets('mismatched config renders the invalid state, never crashes',
        (WidgetTester tester) async {
      await pumpMath(
        tester,
        const MissionEntry(
          id: 1,
          alarmId: 9,
          type: MissionType.math,
          orderIndex: 0,
          config: ShakeMissionConfig(5),
          required: true,
        ),
        onCompleted: () {},
      );
      expect(find.text(en.ringingSkippedInvalid), findsOneWidget);
    });
  });
}
