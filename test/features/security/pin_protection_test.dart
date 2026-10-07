import 'package:alarmx/core/database/database.dart';
import 'package:alarmx/core/l10n/app_strings.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/test_doubles.dart';

// PIN protection tests: Home strict-delete gate + editor Strict toggle,
// ring-proximity blackout, and the mission-section lock. Real in-memory
// stack, English locale.

// Seeds a strict alarm whose next ring is [offset] from now.
Future<int> seedStrictAlarm(TestStack stack, Duration offset) async {
  final int id = await stack.insertAlarm(hour: 7, minute: 30);
  final Alarm? alarm = await stack.repository.getAlarmById(id);
  await stack.repository.updateAlarm(
    alarm!.copyWith(
      strictMode: true,
      nextTriggerAt: Value<DateTime?>(DateTime.now().add(offset)),
    ),
  );
  return id;
}

void main() {
  late TestStack stack;
  final AppStrings en = AppStrings.forCode('en');

  setUp(() {
    stack = TestStack();
  });

  // Each test builds a fresh stack; finishWidgetTest closes it.

  Future<void> tapSave(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('editor_save_button')));
    await pumpSettle(tester);
  }

  Future<void> turnStrictOff(WidgetTester tester) async {
    final Finder strictSwitch =
        find.byKey(const Key('editor_strict_switch'));
    await tester.ensureVisible(strictSwitch);
    await tester.tap(strictSwitch);
    await pumpSettle(tester);
  }

  Future<void> submitPin(WidgetTester tester, String pin) async {
    await tester.enterText(
        find.byKey(const Key('pin_prompt_field')), pin);
    await tester.tap(find.byKey(const Key('pin_prompt_confirm')));
    await pumpSettle(tester);
  }

  group('home strict-delete gate', () {
    testWidgets('strict + PIN prompts; cancel keeps the alarm',
        (WidgetTester tester) async {
      await stack.pinService.setPin(pin: '1234', confirmation: '1234');
      final int id = await seedStrictAlarm(stack, const Duration(hours: 2));
      await pumpHome(tester, stack);

      await tester.tap(find.byKey(Key('alarm_delete_$id')));
      await pumpSettle(tester);

      expect(
        find.byKey(const Key('pin_prompt_field')),
        findsOneWidget,
      );
      await tester.tap(find.text(en.cancel));
      await pumpSettle(tester);
      expect(await stack.repository.getAlarmById(id), isNotNull);
      await finishWidgetTest(tester, stack);
    });

    testWidgets('strict + PIN with a wrong PIN reports and keeps the alarm',
        (WidgetTester tester) async {
      await stack.pinService.setPin(pin: '1234', confirmation: '1234');
      final int id = await seedStrictAlarm(stack, const Duration(hours: 2));
      await pumpHome(tester, stack);

      await tester.tap(find.byKey(Key('alarm_delete_$id')));
      await pumpSettle(tester);
      await submitPin(tester, '0000');

      expect(find.text(en.msgPinIncorrect), findsOneWidget);
      expect(await stack.repository.getAlarmById(id), isNotNull);
      await finishWidgetTest(tester, stack);
    });

    testWidgets('strict + PIN with the correct PIN deletes after confirm',
        (WidgetTester tester) async {
      await stack.pinService.setPin(pin: '1234', confirmation: '1234');
      final int id = await seedStrictAlarm(stack, const Duration(hours: 2));
      await pumpHome(tester, stack);

      await tester.tap(find.byKey(Key('alarm_delete_$id')));
      await pumpSettle(tester);
      await submitPin(tester, '1234');

      expect(find.text(en.deleteTitle), findsOneWidget);
      await tester.tap(find.text(en.delete));
      await pumpSettle(tester);
      expect(await stack.repository.getAlarmById(id), isNull);
      await finishWidgetTest(tester, stack);
    });

    testWidgets('non-strict delete asks no PIN even with a PIN enabled',
        (WidgetTester tester) async {
      await stack.pinService.setPin(pin: '1234', confirmation: '1234');
      final int id = await stack.insertAlarm(hour: 7, minute: 30);
      await pumpHome(tester, stack);

      await tester.tap(find.byKey(Key('alarm_delete_$id')));
      await pumpSettle(tester);

      expect(
        find.byKey(const Key('pin_prompt_field')),
        findsNothing,
      );
      expect(find.text(en.deleteTitle), findsOneWidget);
      await finishWidgetTest(tester, stack);
    });

    testWidgets('strict delete asks no PIN when no PIN is enabled',
        (WidgetTester tester) async {
      final int id = await seedStrictAlarm(stack, const Duration(hours: 2));
      await pumpHome(tester, stack);

      await tester.tap(find.byKey(Key('alarm_delete_$id')));
      await pumpSettle(tester);

      expect(
        find.byKey(const Key('pin_prompt_field')),
        findsNothing,
      );
      expect(find.text(en.deleteTitle), findsOneWidget);
      await finishWidgetTest(tester, stack);
    });
  });

  group('editor strict toggle', () {
    testWidgets('create mode defaults strict from settings',
        (WidgetTester tester) async {
      await stack.settings.getSettings();
      await stack.settings.updateSettings(
        const AppSettingsCompanion(
          strictModeDefault: Value<bool>(true),
        ),
      );
      await pumpEditor(tester, stack);

      final Finder strictSwitch =
          find.byKey(const Key('editor_strict_switch'));
      await tester.ensureVisible(strictSwitch);
      final SwitchListTile tile = tester.widget<SwitchListTile>(
        strictSwitch,
      );
      expect(tile.value, isTrue);
      await finishWidgetTest(tester, stack);
    });

    testWidgets('strict off far from the ring + PIN saves after auth',
        (WidgetTester tester) async {
      await stack.pinService.setPin(pin: '1234', confirmation: '1234');
      final int id = await seedStrictAlarm(stack, const Duration(hours: 2));
      await pumpEditor(tester, stack, alarmId: id);

      await turnStrictOff(tester);
      await tapSave(tester);
      expect(
        find.byKey(const Key('pin_prompt_field')),
        findsOneWidget,
      );
      await submitPin(tester, '1234');

      expect(
        find.byKey(const Key('editor_save_button')),
        findsNothing,
      );
      expect(
        (await stack.repository.getAlarmById(id))!.strictMode,
        isFalse,
      );
      await finishWidgetTest(tester, stack);
    });

    testWidgets('strict off near the ring is blocked without a prompt',
        (WidgetTester tester) async {
      await stack.pinService.setPin(pin: '1234', confirmation: '1234');
      final int id =
          await seedStrictAlarm(stack, const Duration(minutes: 10));
      await pumpEditor(tester, stack, alarmId: id);

      await turnStrictOff(tester);
      await tapSave(tester);

      expect(find.text(en.msgStrictBlackout), findsOneWidget);
      expect(
        find.byKey(const Key('pin_prompt_field')),
        findsNothing,
      );
      expect(
        find.byKey(const Key('editor_save_button')),
        findsOneWidget,
      );
      expect(
        (await stack.repository.getAlarmById(id))!.strictMode,
        isTrue,
      );
      await finishWidgetTest(tester, stack);
    });

    testWidgets('strict off + PIN with a wrong PIN stays open and strict',
        (WidgetTester tester) async {
      await stack.pinService.setPin(pin: '1234', confirmation: '1234');
      final int id = await seedStrictAlarm(stack, const Duration(hours: 2));
      await pumpEditor(tester, stack, alarmId: id);

      await turnStrictOff(tester);
      await tapSave(tester);
      await submitPin(tester, '0000');

      expect(find.text(en.msgPinIncorrect), findsOneWidget);
      expect(
        find.byKey(const Key('editor_save_button')),
        findsOneWidget,
      );
      expect(
        (await stack.repository.getAlarmById(id))!.strictMode,
        isTrue,
      );
      await finishWidgetTest(tester, stack);
    });
  });

  group('editor mission lock', () {
    testWidgets('strict + PIN locks missions until unlocked',
        (WidgetTester tester) async {
      await stack.pinService.setPin(pin: '1234', confirmation: '1234');
      final int id = await seedStrictAlarm(stack, const Duration(hours: 2));
      await pumpEditor(tester, stack, alarmId: id);

      expect(find.text(en.missionLocked), findsOneWidget);
      expect(
        find.byKey(const Key('missions_unlock_button')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('mission_add_button')),
        findsNothing,
      );

      await tester.tap(find.byKey(const Key('missions_unlock_button')));
      await pumpSettle(tester);
      await submitPin(tester, '0000');
      expect(find.text(en.msgPinIncorrect), findsOneWidget);
      expect(find.text(en.missionLocked), findsOneWidget);

      await tester.tap(find.byKey(const Key('missions_unlock_button')));
      await pumpSettle(tester);
      await submitPin(tester, '1234');
      expect(find.text(en.missionLocked), findsNothing);
      expect(
        find.byKey(const Key('mission_add_button')),
        findsOneWidget,
      );
      await finishWidgetTest(tester, stack);
    });

    testWidgets('no lock without strict mode', (WidgetTester tester) async {
      final int plainId = await stack.insertAlarm(hour: 7, minute: 30);
      await pumpEditor(tester, stack, alarmId: plainId);
      expect(find.text(en.missionLocked), findsNothing);
      expect(
        find.byKey(const Key('mission_add_button')),
        findsOneWidget,
      );
      await finishWidgetTest(tester, stack);
    });

    testWidgets('no lock without a PIN', (WidgetTester tester) async {
      final int strictId =
          await seedStrictAlarm(stack, const Duration(hours: 2));
      await pumpEditor(tester, stack, alarmId: strictId);
      expect(find.text(en.missionLocked), findsNothing);
      expect(
        find.byKey(const Key('mission_add_button')),
        findsOneWidget,
      );
      await finishWidgetTest(tester, stack);
    });
  });
}
