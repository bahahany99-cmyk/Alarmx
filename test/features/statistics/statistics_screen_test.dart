import 'package:alarmx/core/database/database.dart';
import 'package:alarmx/core/l10n/app_strings.dart';
import 'package:alarmx/core/models/models.dart';
import 'package:alarmx/features/statistics/statistics_calculator.dart';
import 'package:alarmx/features/statistics/statistics_screen.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/test_doubles.dart';

// StatisticsScreen tests: real in-memory stack, English locale unless stated.
// Fixtures are seeded relative to the production week boundary (pinned by the
// calculator tests), so they hold on any day the suite runs.

Future<void> pumpStats(
  WidgetTester tester,
  TestStack stack, {
  String language = AppLanguage.english,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      locale: Locale(language),
      supportedLocales: testLocales,
      localizationsDelegates: testDelegates,
      home: StatisticsScreen(
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

  Future<void> insertRow({
    int? alarmId,
    required DateTime startedAt,
    DateTime? stoppedAt,
    AlarmResult result = AlarmResult.success,
  }) {
    return stack.history.insertHistory(
      AlarmHistoryCompanion.insert(
        alarmId: Value<int?>(alarmId),
        startedAt: startedAt,
        stoppedAt: Value<DateTime?>(stoppedAt),
        result: Value<String>(result.dbValue),
      ),
    );
  }

  test('formatStopDuration renders M:SS', () {
    expect(formatStopDuration(const Duration(seconds: 5)), '0:05');
    expect(formatStopDuration(const Duration(seconds: 90)), '1:30');
    expect(formatStopDuration(const Duration(seconds: 3599)), '59:59');
    expect(formatStopDuration(const Duration(seconds: 3600)), '60:00');
  });

  testWidgets('empty week shows zeros and unavailable metrics',
      (WidgetTester tester) async {
    await pumpStats(tester, stack);

    expect(find.text(en.statisticsTitle), findsOneWidget);
    expect(find.text(en.statisticsCompleted), findsOneWidget);
    expect(find.text(en.statisticsFailed), findsOneWidget);
    expect(find.text('0'), findsNWidgets(2));
    expect(find.text(en.statisticsUnavailable), findsNWidgets(3));
    await finishWidgetTest(tester, stack);
  });

  testWidgets('populated week renders real metrics',
      (WidgetTester tester) async {
    final DateTime weekStart = startOfWeekLocal(DateTime.now());
    final int alarmId =
        await stack.insertAlarm(hour: 7, minute: 30, label: 'Work');
    DateTime day(int offset) =>
        weekStart.add(Duration(days: offset, hours: 6));
    await insertRow(
      alarmId: alarmId,
      startedAt: day(1),
      stoppedAt: day(1).add(const Duration(seconds: 90)),
    );
    await insertRow(
      alarmId: alarmId,
      startedAt: day(2),
      stoppedAt: day(2).add(const Duration(seconds: 150)),
    );
    await insertRow(
      alarmId: alarmId,
      startedAt: day(3),
      stoppedAt: day(3).add(const Duration(seconds: 30)),
      result: AlarmResult.failed,
    );
    // Pre-week row: must not leak into any metric.
    await insertRow(
      alarmId: alarmId,
      startedAt: weekStart.subtract(const Duration(hours: 1)),
      stoppedAt: weekStart.add(const Duration(hours: 3)),
    );
    await pumpStats(tester, stack);

    expect(find.text('2'), findsOneWidget);
    expect(find.text('1'), findsOneWidget);
    expect(find.text('1:30'), findsNWidgets(2));
    expect(find.text('0:30'), findsOneWidget);
    expect(find.text('Work'), findsOneWidget);
    await finishWidgetTest(tester, stack);
  });

  testWidgets('hardest falls back for missing alarms',
      (WidgetTester tester) async {
    final DateTime weekStart = startOfWeekLocal(DateTime.now());
    await insertRow(
      alarmId: 999,
      startedAt: weekStart.add(const Duration(days: 1)),
      stoppedAt: weekStart.add(
        const Duration(days: 1, seconds: 200),
      ),
    );
    await insertRow(
      startedAt: weekStart.add(const Duration(days: 2)),
      stoppedAt: weekStart.add(
        const Duration(days: 2, seconds: 100),
      ),
    );
    await pumpStats(tester, stack);

    expect(
      find.text('${en.historyUnknownAlarm} #999'),
      findsOneWidget,
    );
    expect(find.text('3:20'), findsOneWidget);
    await finishWidgetTest(tester, stack);
  });

  testWidgets('null identity hardest uses the plain fallback',
      (WidgetTester tester) async {
    final DateTime weekStart = startOfWeekLocal(DateTime.now());
    await insertRow(
      startedAt: weekStart.add(const Duration(days: 1)),
      stoppedAt: weekStart.add(
        const Duration(days: 1, seconds: 100),
      ),
    );
    await pumpStats(tester, stack);

    expect(find.text(en.historyUnknownAlarm), findsOneWidget);
    await finishWidgetTest(tester, stack);
  });

  testWidgets('metrics update when history changes',
      (WidgetTester tester) async {
    await pumpStats(tester, stack);
    expect(find.text(en.statisticsUnavailable), findsNWidgets(3));

    final DateTime weekStart = startOfWeekLocal(DateTime.now());
    final DateTime startedAt = weekStart.add(const Duration(days: 1));
    await insertRow(
      startedAt: startedAt,
      stoppedAt: startedAt.add(const Duration(seconds: 5)),
    );
    await pumpSettle(tester);

    expect(find.text('1'), findsOneWidget);
    expect(find.text('0:05'), findsNWidgets(3));
    await finishWidgetTest(tester, stack);
  });

  testWidgets('arabic locale renders RTL labels',
      (WidgetTester tester) async {
    await pumpStats(tester, stack, language: AppLanguage.arabic);

    expect(find.text(ar.statisticsTitle), findsOneWidget);
    expect(find.text(ar.statisticsCompleted), findsOneWidget);
    expect(find.text(ar.statisticsUnavailable), findsNWidgets(3));
    final Directionality directionality =
        tester.widget(find.byType(Directionality).first);
    expect(directionality.textDirection, TextDirection.rtl);
    await finishWidgetTest(tester, stack);
  });

  testWidgets('home statistics button opens the screen',
      (WidgetTester tester) async {
    await pumpHome(tester, stack);

    await tester.tap(find.byKey(const Key('home_statistics_button')));
    await pumpSettle(tester);

    expect(find.text(en.statisticsTitle), findsOneWidget);
    await finishWidgetTest(tester, stack);
  });
}
