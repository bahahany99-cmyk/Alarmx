import 'package:alarmx/core/database/database.dart';
import 'package:alarmx/core/l10n/app_strings.dart';
import 'package:alarmx/features/security/security_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/test_doubles.dart';

// SecurityScreen tests: real in-memory stack, English locale.

Future<void> pumpSecurity(WidgetTester tester, TestStack stack) async {
  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('en'),
      supportedLocales: testLocales,
      localizationsDelegates: testDelegates,
      home: SecurityScreen(
        settings: stack.settings,
        pinService: stack.pinService,
      ),
    ),
  );
  await pumpSettle(tester);
}

void main() {
  late TestStack stack;
  final AppStrings en = AppStrings.forCode('en');

  setUp(() {
    stack = TestStack();
  });

  // Each test builds a fresh stack; finishWidgetTest closes it.

  testWidgets('disabled status with an enable button by default',
      (WidgetTester tester) async {
    await pumpSecurity(tester, stack);

    expect(find.text(en.securityTitle), findsWidgets);
    expect(find.text(en.pinStatusDisabled), findsOneWidget);
    expect(
      find.byKey(const Key('security_enable_pin_button')),
      findsOneWidget,
    );
    await finishWidgetTest(tester, stack);
  });

  testWidgets('enable flow stores the PIN and shows enabled',
      (WidgetTester tester) async {
    await pumpSecurity(tester, stack);

    await tester.tap(find.byKey(const Key('security_enable_pin_button')));
    await pumpSettle(tester);
    await tester.enterText(
        find.byKey(const Key('pin_setup_new')), '1234');
    await tester.enterText(
        find.byKey(const Key('pin_setup_confirm')), '1234');
    await tester.tap(find.byKey(const Key('pin_setup_save')));
    await pumpSettle(tester);

    expect(await stack.pinService.isPinEnabled(), isTrue);
    expect(find.text(en.pinStatusEnabled), findsOneWidget);
    await finishWidgetTest(tester, stack);
  });

  testWidgets('enable mismatch reports inline and stays open',
      (WidgetTester tester) async {
    await pumpSecurity(tester, stack);

    await tester.tap(find.byKey(const Key('security_enable_pin_button')));
    await pumpSettle(tester);
    await tester.enterText(
        find.byKey(const Key('pin_setup_new')), '1234');
    await tester.enterText(
        find.byKey(const Key('pin_setup_confirm')), '5678');
    await tester.tap(find.byKey(const Key('pin_setup_save')));
    await pumpSettle(tester);

    expect(find.text(en.msgPinMismatch), findsOneWidget);
    expect(find.byKey(const Key('pin_setup_save')), findsOneWidget);
    expect(await stack.pinService.isPinEnabled(), isFalse);
    await finishWidgetTest(tester, stack);
  });

  testWidgets('change with a wrong current PIN reports inline',
      (WidgetTester tester) async {
    await stack.pinService.setPin(pin: '1234', confirmation: '1234');
    await pumpSecurity(tester, stack);

    await tester.tap(find.byKey(const Key('security_change_pin_button')));
    await pumpSettle(tester);
    await tester.enterText(
        find.byKey(const Key('pin_setup_current')), '0000');
    await tester.enterText(
        find.byKey(const Key('pin_setup_new')), '5678');
    await tester.enterText(
        find.byKey(const Key('pin_setup_confirm')), '5678');
    await tester.tap(find.byKey(const Key('pin_setup_save')));
    await pumpSettle(tester);

    expect(find.text(en.msgPinIncorrect), findsOneWidget);
    expect(await stack.pinService.verifyPin('1234'), isTrue);
    await finishWidgetTest(tester, stack);
  });

  testWidgets('disable with the correct PIN switches protection off',
      (WidgetTester tester) async {
    await stack.pinService.setPin(pin: '1234', confirmation: '1234');
    await pumpSecurity(tester, stack);

    await tester.tap(find.byKey(const Key('security_disable_pin_button')));
    await pumpSettle(tester);
    await tester.enterText(
        find.byKey(const Key('pin_prompt_field')), '1234');
    await tester.tap(find.byKey(const Key('pin_prompt_confirm')));
    await pumpSettle(tester);

    expect(await stack.pinService.isPinEnabled(), isFalse);
    expect(find.text(en.pinStatusDisabled), findsOneWidget);
    await finishWidgetTest(tester, stack);
  });

  testWidgets('disable with a wrong PIN reports and stays enabled',
      (WidgetTester tester) async {
    await stack.pinService.setPin(pin: '1234', confirmation: '1234');
    await pumpSecurity(tester, stack);

    await tester.tap(find.byKey(const Key('security_disable_pin_button')));
    await pumpSettle(tester);
    await tester.enterText(
        find.byKey(const Key('pin_prompt_field')), '0000');
    await tester.tap(find.byKey(const Key('pin_prompt_confirm')));
    await pumpSettle(tester);

    expect(find.text(en.msgPinIncorrect), findsOneWidget);
    expect(await stack.pinService.isPinEnabled(), isTrue);
    await finishWidgetTest(tester, stack);
  });

  testWidgets('strict default toggle persists', (WidgetTester tester) async {
    await pumpSecurity(tester, stack);

    await tester.tap(
      find.byKey(const Key('security_strict_default_switch')),
    );
    await pumpSettle(tester);

    final AppSetting stored = await stack.settings.getSettings();
    expect(stored.strictModeDefault, isTrue);
    await finishWidgetTest(tester, stack);
  });
}
