import 'package:alarmx/core/database/database.dart';
import 'package:alarmx/core/l10n/app_strings.dart';
import 'package:alarmx/core/models/models.dart';
import 'package:alarmx/features/history/history_screen.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/test_doubles.dart';

// HistoryScreen tests: real in-memory stack, English locale unless stated.

Future<void> pumpHistory(
  WidgetTester tester,
  TestStack stack, {
  String language = AppLanguage.english,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      locale: Locale(language),
      supportedLocales: testLocales,
      localizationsDelegates: testDelegates,
      home: HistoryScreen(
        history: stack.history,
        alarms: stack.repository,
      ),
    ),
  );
  await pumpSettle(tester);
}

void main() {
  late TestStack stack;
  final AppStrings en = AppStrings.forCode('en');
  final AppStrings ar = AppStrings.forCode('ar');

  setUp(() {
    stack = TestStack();
  });

  // Each test builds a fresh stack; finishWidgetTest closes it.

  // Whole-second timestamps: drift stores DateTimes at second precision.
  DateTime at(int day, int hour, int minute) =>
      DateTime(2026, 10, day, hour, minute);

  Future<int> insertRow({
    int? alarmId,
    required DateTime startedAt,
    DateTime? stoppedAt,
    AlarmResult result = AlarmResult.ongoing,
    int attempts = 0,
    int snoozeCount = 0,
  }) {
    return stack.history.insertHistory(
      AlarmHistoryCompanion.insert(
        alarmId: Value<int?>(alarmId),
        startedAt: startedAt,
        stoppedAt: Value<DateTime?>(stoppedAt),
        result: Value<String>(result.dbValue),
        attempts: Value<int>(attempts),
        snoozeCount: Value<int>(snoozeCount),
      ),
    );
  }

  testWidgets('empty state is localized', (WidgetTester tester) async {
    await pumpHistory(tester, stack);

    expect(find.text(en.historyTitle), findsOneWidget);
    expect(find.text(en.historyEmptyTitle), findsOneWidget);
    expect(find.text(en.historyEmptySubtitle), findsOneWidget);
    await finishWidgetTest(tester, stack);
  });

  testWidgets('entries show statuses and expand to metadata',
      (WidgetTester tester) async {
    final int alarmId =
        await stack.insertAlarm(hour: 7, minute: 30, label: 'Work');
    final int okId = await insertRow(
      alarmId: alarmId,
      startedAt: at(3, 6, 0),
      stoppedAt: at(3, 6, 4),
      result: AlarmResult.success,
      attempts: 3,
      snoozeCount: 2,
    );
    await insertRow(
      alarmId: alarmId,
      startedAt: at(2, 6, 0),
      stoppedAt: at(2, 6, 1),
      result: AlarmResult.failed,
    );
    await insertRow(
      alarmId: alarmId,
      startedAt: at(1, 6, 0),
      stoppedAt: at(1, 6, 2),
      result: AlarmResult.emergencyStop,
    );
    await pumpHistory(tester, stack);

    expect(find.text('Work'), findsNWidgets(3));
    expect(find.text(en.historyStatusSuccess), findsOneWidget);
    expect(find.text(en.historyStatusFailed), findsOneWidget);
    expect(find.text(en.historyStatusEmergency), findsOneWidget);
    // The start line is '$date $time' from framework formatters: only the
    // time half is asserted ('6:0' mirrors the proven '7:00' editor asserts).
    // Date wording and digit shapes are framework territory in every locale.
    expect(find.textContaining('6:0'), findsWidgets);

    await tester.tap(find.byKey(Key('history_tile_$okId')));
    await pumpSettle(tester);
    expect(find.text(en.historyStart), findsOneWidget);
    expect(find.text(en.historyStop), findsOneWidget);
    expect(find.text(en.historyResult), findsOneWidget);
    expect(find.text(en.historyAttempts), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
    expect(find.text(en.historySnoozes), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    await finishWidgetTest(tester, stack);
  });

  testWidgets('missing alarms render a safe fallback',
      (WidgetTester tester) async {
    await insertRow(alarmId: 999, startedAt: at(2, 6, 0));
    await insertRow(alarmId: null, startedAt: at(1, 6, 0));
    await pumpHistory(tester, stack);

    expect(
      find.text('${en.historyUnknownAlarm} #999'),
      findsOneWidget,
    );
    expect(find.text(en.historyUnknownAlarm), findsOneWidget);
    await finishWidgetTest(tester, stack);
  });

  testWidgets('newest entry renders first', (WidgetTester tester) async {
    final int firstId =
        await stack.insertAlarm(hour: 6, minute: 0, label: 'First');
    final int secondId =
        await stack.insertAlarm(hour: 7, minute: 0, label: 'Second');
    await insertRow(alarmId: firstId, startedAt: at(1, 6, 0));
    await insertRow(alarmId: secondId, startedAt: at(2, 6, 0));
    await pumpHistory(tester, stack);

    final double firstDy = tester.getTopLeft(find.text('First')).dy;
    final double secondDy = tester.getTopLeft(find.text('Second')).dy;
    expect(secondDy < firstDy, isTrue);
    await finishWidgetTest(tester, stack);
  });

  testWidgets('list updates when history changes',
      (WidgetTester tester) async {
    await pumpHistory(tester, stack);
    expect(find.text(en.historyEmptyTitle), findsOneWidget);

    await insertRow(
      startedAt: at(1, 6, 0),
      stoppedAt: at(1, 6, 5),
      result: AlarmResult.success,
    );
    await pumpSettle(tester);

    expect(find.text(en.historyEmptyTitle), findsNothing);
    expect(find.text(en.historyStatusSuccess), findsOneWidget);
    await finishWidgetTest(tester, stack);
  });

  testWidgets('arabic locale renders RTL labels',
      (WidgetTester tester) async {
    await pumpHistory(tester, stack, language: AppLanguage.arabic);

    expect(find.text(ar.historyTitle), findsOneWidget);
    expect(find.text(ar.historyEmptyTitle), findsOneWidget);
    final Directionality directionality =
        tester.widget(find.byType(Directionality).first);
    expect(directionality.textDirection, TextDirection.rtl);
    await finishWidgetTest(tester, stack);
  });

  testWidgets('home history button opens the screen',
      (WidgetTester tester) async {
    await pumpHome(tester, stack);

    await tester.tap(find.byKey(const Key('home_history_button')));
    await pumpSettle(tester);

    expect(find.text(en.historyTitle), findsOneWidget);
    await finishWidgetTest(tester, stack);
  });
}
