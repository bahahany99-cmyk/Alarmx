// Tests for the typing mission: deterministic answer checking plus the
// execution widget (render, retry, single completion, no double-submit).

import 'package:alarmx/core/l10n/app_strings.dart';
import 'package:alarmx/core/models/models.dart';
import 'package:alarmx/features/missions/mission_config.dart';
import 'package:alarmx/features/missions/typing/typing_mission.dart';
import 'package:alarmx/features/missions/typing/typing_mission_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/test_doubles.dart';

MissionEntry typingEntry(TypingMissionConfig config) {
  return MissionEntry(
    id: 1,
    alarmId: 9,
    type: MissionType.typing,
    orderIndex: 0,
    config: config,
    required: true,
  );
}

Future<void> pumpTyping(
  WidgetTester tester,
  MissionEntry entry, {
  required VoidCallback onCompleted,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale(AppLanguage.english),
      supportedLocales: testLocales,
      localizationsDelegates: testDelegates,
      home: Scaffold(
        body: SingleChildScrollView(
          child: TypingMissionWidget(
            entry: entry,
            onCompleted: onCompleted,
          ),
        ),
      ),
    ),
  );
  await pumpSettle(tester);
}

void main() {
  group('checkTypingAnswer', () {
    const TypingMissionConfig config = TypingMissionConfig('wake up');

    test('correct text succeeds', () {
      expect(checkTypingAnswer(config, 'wake up'), isTrue);
    });

    test('surrounding whitespace is ignored on both sides', () {
      expect(checkTypingAnswer(config, '  wake up  '), isTrue);
      const TypingMissionConfig padded = TypingMissionConfig('  wake up ');
      expect(checkTypingAnswer(padded, 'wake up'), isTrue);
    });

    test('incorrect text fails', () {
      expect(checkTypingAnswer(config, 'wake  up'), isFalse);
      expect(checkTypingAnswer(config, 'Wake up'), isFalse);
      expect(checkTypingAnswer(config, 'wake up!'), isFalse);
      expect(checkTypingAnswer(config, 'wake'), isFalse);
    });

    test('empty input never succeeds', () {
      expect(checkTypingAnswer(config, ''), isFalse);
      expect(checkTypingAnswer(config, '   '), isFalse);
      expect(
        checkTypingAnswer(const TypingMissionConfig(''), ''),
        isFalse,
      );
      expect(
        checkTypingAnswer(const TypingMissionConfig('   '), 'x'),
        isFalse,
      );
    });

    test('checking is repeatable (attempts do not consume anything)', () {
      expect(checkTypingAnswer(config, 'no'), isFalse);
      expect(checkTypingAnswer(config, 'still no'), isFalse);
      expect(checkTypingAnswer(config, 'wake up'), isTrue);
      expect(checkTypingAnswer(config, 'wake up'), isTrue);
    });
  });

  group('TypingMissionWidget', () {
    final AppStrings en = AppStrings.forCode(AppLanguage.english);

    testWidgets('renders instruction, text, field and button',
        (WidgetTester tester) async {
      await pumpTyping(
        tester,
        typingEntry(const TypingMissionConfig('wake up')),
        onCompleted: () {},
      );
      expect(find.text(en.typingInstruction), findsOneWidget);
      expect(find.text('wake up'), findsOneWidget);
      expect(find.byKey(const Key('typing_answer_field')), findsOneWidget);
      expect(find.byKey(const Key('typing_check_button')), findsOneWidget);
    });

    testWidgets('wrong answer shows failure and stays on the mission',
        (WidgetTester tester) async {
      int completions = 0;
      await pumpTyping(
        tester,
        typingEntry(const TypingMissionConfig('wake up')),
        onCompleted: () {
          completions++;
        },
      );
      await tester.enterText(
        find.byKey(const Key('typing_answer_field')),
        'wrong',
      );
      await tester.tap(find.byKey(const Key('typing_check_button')));
      await pumpSettle(tester);
      expect(find.text(en.missionIncorrect), findsOneWidget);
      expect(completions, 0);
      // Retry with the correct text succeeds.
      await tester.enterText(
        find.byKey(const Key('typing_answer_field')),
        'wake up',
      );
      await tester.tap(find.byKey(const Key('typing_check_button')));
      await pumpSettle(tester);
      expect(completions, 1);
    });

    testWidgets('correct answer completes exactly once',
        (WidgetTester tester) async {
      int completions = 0;
      await pumpTyping(
        tester,
        typingEntry(const TypingMissionConfig('wake up')),
        onCompleted: () {
          completions++;
        },
      );
      await tester.enterText(
        find.byKey(const Key('typing_answer_field')),
        '  wake up ',
      );
      await tester.tap(find.byKey(const Key('typing_check_button')));
      await pumpSettle(tester);
      expect(completions, 1);
      expect(find.text(en.missionCompleted), findsOneWidget);
      // The disabled button cannot report twice.
      await tester.tap(
        find.byKey(const Key('typing_check_button')),
        warnIfMissed: false,
      );
      await pumpSettle(tester);
      expect(completions, 1);
    });

    testWidgets('mismatched config renders the invalid state, never crashes',
        (WidgetTester tester) async {
      await pumpTyping(
        tester,
        const MissionEntry(
          id: 1,
          alarmId: 9,
          type: MissionType.typing,
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
