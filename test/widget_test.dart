import 'package:alarmx/core/l10n/app_strings.dart';
import 'package:alarmx/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/test_doubles.dart';

// App-shell tests: the production AlarmxApp with a real in-memory stack.

void main() {
  late TestStack stack;

  setUp(() {
    stack = TestStack();
  });

  tearDown(() async {
    // Dispose widgets FIRST (cancels Drift watch subscriptions), then close
    // the database. Deterministic per-test cleanup: no leaked connections
    // accumulate across the suite.
    await disposeLastTree();
    await stack.close();
  });

  testWidgets('app shell shows the home screen', (WidgetTester tester) async {
    await pumpAlarmxApp(tester, stack);

    expect(find.text(AppStrings.forCode('en').homeTitle), findsOneWidget);
    expect(
      find.text(AppStrings.forCode('en').homeEmptyTitle),
      findsOneWidget,
    );
    expect(find.byKey(const Key('add_alarm_fab')), findsOneWidget);
  });

  testWidgets('schema-default Arabic renders an RTL UI',
      (WidgetTester tester) async {
    // No language forced: the settings row is created with schema default.
    await tester.pumpWidget(
      AlarmxApp(
        repository: stack.repository,
        coordinator: stack.coordinator,
        settings: stack.settings,
      ),
    );
    await pumpSettle(tester);

    expect(find.text(AppStrings.forCode('ar').homeTitle), findsOneWidget);
    final Directionality directionality =
        tester.widget(find.byType(Directionality).first);
    expect(directionality.textDirection, TextDirection.rtl);
  });

  testWidgets('language menu switches and persists the language',
      (WidgetTester tester) async {
    await pumpAlarmxApp(tester, stack, language: 'ar');
    expect(find.text(AppStrings.forCode('ar').homeTitle), findsOneWidget);

    await tester.tap(find.byIcon(Icons.language));
    await pumpSettle(tester);
    await tester.tap(find.text(AppStrings.forCode('ar').langEnglish));
    await pumpSettle(tester);

    expect(find.text(AppStrings.forCode('en').homeTitle), findsOneWidget);
    expect((await stack.settings.getSettings()).language, 'en');
  });
}
