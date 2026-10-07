import 'package:alarmx/core/database/database.dart';
import 'package:alarmx/core/l10n/app_strings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/test_doubles.dart';

// Editor tests: real in-memory stack, English locale. Save outcomes are
// asserted through repository + fake scheduler state; result-message
// mapping is covered by the controller tests.

void main() {
  late TestStack stack;
  final AppStrings en = AppStrings.forCode('en');

  setUp(() {
    stack = TestStack();
  });

  // NOTE: the stack is intentionally not closed. Group tearDown runs before
  // postTest disposes the widget tree, so closing here shuts the Drift store
  // while StreamBuilders still hold watch subscriptions; their later cancel
  // then traps a zero-duration Timer (StreamQueryStore.markAsClosed) that is
  // still pending at the postTest check and fails the test. Each test builds
  // a fresh stack; the isolate exit reclaims the abandoned in-memory DB.

  Future<List<Alarm>> alarms() => stack.repository.getAlarms();

  Future<int> missionRowCount() async {
    final row = await stack.db
        .customSelect('SELECT COUNT(*) AS c FROM missions')
        .getSingle();
    return row.read<int>('c');
  }

  Future<void> tapVisible(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await pumpSettle(tester);
    await tester.tap(finder);
    await pumpSettle(tester);
  }

  group('create defaults', () {
    testWidgets('renders the default form', (WidgetTester tester) async {
      await pumpEditor(tester, stack);
      // The snooze chips sit below the fold in a lazily-built list; scroll
      // so they build before asserting on them.
      await tester.drag(find.byType(ListView), const Offset(0, -500));
      await pumpSettle(tester);

      expect(find.text(en.createAlarmTitle), findsOneWidget);
      expect(find.textContaining('7:00'), findsOneWidget);
      expect(find.text(en.repeatDaily), findsOneWidget);
      // Once-only and custom-only controls are hidden for daily.
      expect(find.byKey(const Key('editor_date_button')), findsNothing);
      expect(find.text('Mon'), findsNothing);
      // Snooze is enabled by default, so its chips show.
      expect(find.text('5'), findsOneWidget);
      expect(find.text(en.missionNone), findsOneWidget);
      expect(find.byKey(const Key('editor_save_button')), findsOneWidget);
      await finishWidgetTest(tester, stack);
    });

    testWidgets('label entry is kept', (WidgetTester tester) async {
      await pumpEditor(tester, stack);
      await tester.enterText(
        find.byKey(const Key('editor_label_field')),
        'Gym',
      );
      await tester.pump();
      expect(find.text('Gym'), findsOneWidget);
      await finishWidgetTest(tester, stack);
    });

    testWidgets('once shows the date picker button',
        (WidgetTester tester) async {
      await pumpEditor(tester, stack);
      await tapVisible(tester, find.text(en.repeatOnce));
      expect(find.byKey(const Key('editor_date_button')), findsOneWidget);
      await finishWidgetTest(tester, stack);
    });

    testWidgets('custom shows weekday chips', (WidgetTester tester) async {
      await pumpEditor(tester, stack);
      await tapVisible(tester, find.text(en.repeatCustom));
      for (final String day in <String>[
        'Sun',
        'Mon',
        'Tue',
        'Wed',
        'Thu',
        'Fri',
        'Sat',
      ]) {
        expect(find.text(day), findsOneWidget);
      }
      await finishWidgetTest(tester, stack);
    });
  });

  group('create save', () {
    testWidgets('daily alarm with label is saved and scheduled',
        (WidgetTester tester) async {
      await pumpEditor(tester, stack);
      await tester.enterText(
        find.byKey(const Key('editor_label_field')),
        'Work',
      );
      await tester.pump();
      await tester.tap(find.byKey(const Key('editor_save_button')));
      await pumpSettle(tester);

      // Popped back.
      expect(find.byKey(const Key('editor_save_button')), findsNothing);
      final List<Alarm> rows = await alarms();
      expect(rows, hasLength(1));
      expect(rows.single.label, 'Work');
      expect(rows.single.hour, 7);
      expect(rows.single.repeatType, 'daily');
      expect(rows.single.nextTriggerAt, isNotNull);
      expect(stack.scheduler.scheduledIds, <int>[rows.single.id]);
      await finishWidgetTest(tester, stack);
    });

    testWidgets('custom days are stored as the typed bitmask',
        (WidgetTester tester) async {
      await pumpEditor(tester, stack);
      await tapVisible(tester, find.text(en.repeatCustom));
      await tapVisible(tester, find.text('Mon'));
      await tapVisible(tester, find.text('Wed'));
      await tester.tap(find.byKey(const Key('editor_save_button')));
      await pumpSettle(tester);

      final List<Alarm> rows = await alarms();
      expect(rows, hasLength(1));
      expect(rows.single.repeatType, 'custom');
      expect(rows.single.repeatDays, 2 | 8);
      await finishWidgetTest(tester, stack);
    });

    testWidgets('custom with no day blocks saving',
        (WidgetTester tester) async {
      await pumpEditor(tester, stack);
      await tapVisible(tester, find.text(en.repeatCustom));
      await tester.tap(find.byKey(const Key('editor_save_button')));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.text(en.msgValidationDays), findsOneWidget);
      expect(find.byKey(const Key('editor_save_button')), findsOneWidget);
      expect(await alarms(), isEmpty);
      await finishWidgetTest(tester, stack);
    });

    testWidgets('disabled alarm is saved without a schedule',
        (WidgetTester tester) async {
      await pumpEditor(tester, stack);
      await tapVisible(
        tester,
        find.ancestor(
          of: find.text('On'),
          matching: find.byType(SwitchListTile),
        ),
      );
      expect(find.text('Off'), findsOneWidget);
      await tester.tap(find.byKey(const Key('editor_save_button')));
      await pumpSettle(tester);

      final List<Alarm> rows = await alarms();
      expect(rows.single.enabled, isFalse);
      expect(stack.scheduler.scheduledIds, isEmpty);
      await finishWidgetTest(tester, stack);
    });

    testWidgets('vibration off reaches the frozen fire config',
        (WidgetTester tester) async {
      await pumpEditor(tester, stack);
      await tapVisible(
        tester,
        find.ancestor(
          of: find.text(en.vibrationLabel),
          matching: find.byType(SwitchListTile),
        ),
      );
      await tester.tap(find.byKey(const Key('editor_save_button')));
      await pumpSettle(tester);

      expect((await alarms()).single.vibrationEnabled, isFalse);
      expect(
        stack.scheduler.scheduledConfigs.single?.vibrationEnabled,
        isFalse,
      );
      await finishWidgetTest(tester, stack);
    });

    testWidgets('custom sound URI is stored', (WidgetTester tester) async {
      await pumpEditor(tester, stack);
      await tapVisible(tester, find.text(en.soundCustom));
      await tester.enterText(
        find.byKey(const Key('editor_sound_uri_field')),
        'content://tones/x',
      );
      await tester.pump();
      await tester.tap(find.byKey(const Key('editor_save_button')));
      await pumpSettle(tester);

      final Alarm row = (await alarms()).single;
      expect(row.soundUri, 'content://tones/x');
      expect(row.soundType, 'custom');
      await finishWidgetTest(tester, stack);
    });

    testWidgets('back to default clears the URI', (WidgetTester tester) async {
      await pumpEditor(tester, stack);
      await tapVisible(tester, find.text(en.soundCustom));
      await tester.enterText(
        find.byKey(const Key('editor_sound_uri_field')),
        'content://tones/x',
      );
      await tapVisible(tester, find.text(en.soundDefault));

      expect(find.text('content://tones/x'), findsNothing);
      await finishWidgetTest(tester, stack);
    });

    testWidgets('volume change is stored', (WidgetTester tester) async {
      await pumpEditor(tester, stack);
      final Finder slider = find.byType(Slider);
      await tester.ensureVisible(slider);
      await pumpSettle(tester);
      await tester.drag(slider, const Offset(-120, 0));
      await pumpSettle(tester);
      await tester.tap(find.byKey(const Key('editor_save_button')));
      await pumpSettle(tester);

      final int volume = (await alarms()).single.volume;
      expect(volume, lessThan(80));
      await finishWidgetTest(tester, stack);
    });

    testWidgets('fade-in toggle is stored', (WidgetTester tester) async {
      await pumpEditor(tester, stack);
      await tapVisible(
        tester,
        find.ancestor(
          of: find.text(en.fadeInLabel),
          matching: find.byType(SwitchListTile),
        ),
      );
      await tester.tap(find.byKey(const Key('editor_save_button')));
      await pumpSettle(tester);

      expect((await alarms()).single.fadeInEnabled, isTrue);
      await finishWidgetTest(tester, stack);
    });

    testWidgets('snooze off hides options and is stored',
        (WidgetTester tester) async {
      await pumpEditor(tester, stack);
      await tapVisible(
        tester,
        find.byKey(const Key('editor_snooze_switch')),
      );
      expect(find.text('5'), findsNothing);
      await tester.tap(find.byKey(const Key('editor_save_button')));
      await pumpSettle(tester);

      expect((await alarms()).single.snoozeEnabled, isFalse);
      await finishWidgetTest(tester, stack);
    });

    testWidgets('snooze duration and max count are stored',
        (WidgetTester tester) async {
      await pumpEditor(tester, stack);
      await tapVisible(tester, find.text('15'));
      await tapVisible(tester, find.byType(DropdownButton<int>));
      await tester.tap(find.text('5').last);
      await pumpSettle(tester);
      await tester.tap(find.byKey(const Key('editor_save_button')));
      await pumpSettle(tester);

      final Alarm row = (await alarms()).single;
      expect(row.snoozeMinutes, 15);
      expect(row.snoozeMaxCount, 5);
      await finishWidgetTest(tester, stack);
    });

    testWidgets('mission section creates no mission rows',
        (WidgetTester tester) async {
      await pumpEditor(tester, stack);
      expect(find.text(en.missionTitle), findsOneWidget);
      await tester.tap(find.byKey(const Key('editor_save_button')));
      await pumpSettle(tester);

      expect(await missionRowCount(), 0);
      await finishWidgetTest(tester, stack);
    });
  });

  group('pickers', () {
    testWidgets('time picker opens and keeps the value on OK',
        (WidgetTester tester) async {
      await pumpEditor(tester, stack);
      await tester.tap(find.byKey(const Key('editor_time_button')));
      await pumpSettle(tester);
      expect(find.byType(TimePickerDialog), findsOneWidget);

      await tester.tap(find.text('OK'));
      await pumpSettle(tester);
      expect(find.byType(TimePickerDialog), findsNothing);
      expect(find.textContaining('7:00'), findsOneWidget);
      await finishWidgetTest(tester, stack);
    });

    testWidgets('date picker opens for once alarms',
        (WidgetTester tester) async {
      await pumpEditor(tester, stack);
      await tapVisible(tester, find.text(en.repeatOnce));
      await tester.tap(find.byKey(const Key('editor_date_button')));
      await pumpSettle(tester);
      expect(find.byType(DatePickerDialog), findsOneWidget);

      await tester.tap(find.text('OK'));
      await pumpSettle(tester);
      expect(find.byType(DatePickerDialog), findsNothing);
      await finishWidgetTest(tester, stack);
    });
  });

  group('edit', () {
    testWidgets('existing values load', (WidgetTester tester) async {
      final int id = await stack.insertAlarm(
        hour: 6,
        minute: 15,
        label: 'Work',
      );
      await pumpEditor(tester, stack, alarmId: id);

      expect(find.text('Work'), findsOneWidget);
      expect(find.textContaining('6:15'), findsOneWidget);
      expect(find.text(en.editAlarmTitle), findsOneWidget);
      await finishWidgetTest(tester, stack);
    });

    testWidgets('modified alarm is updated and rescheduled',
        (WidgetTester tester) async {
      final int id = await stack.insertAlarm(hour: 7, label: 'Old');
      await stack.coordinator.scheduleAlarm(id);
      stack.scheduler.calls.clear();
      stack.scheduler.scheduledTriggers.clear();
      await pumpEditor(tester, stack, alarmId: id);

      await tester.enterText(
        find.byKey(const Key('editor_label_field')),
        'New',
      );
      await tester.pump();
      await tester.tap(find.byKey(const Key('editor_save_button')));
      await pumpSettle(tester);

      final Alarm? stored = await stack.repository.getAlarmById(id);
      expect(stored?.label, 'New');
      expect(stack.scheduler.calls, <String>['cancel:$id', 'schedule:$id']);
      expect(stored?.nextTriggerAt,
          stack.scheduler.scheduledTriggers.single);
      await finishWidgetTest(tester, stack);
    });

    testWidgets('disabling edit cancels the schedule',
        (WidgetTester tester) async {
      final int id = await stack.insertAlarm(hour: 7);
      await stack.coordinator.scheduleAlarm(id);
      await pumpEditor(tester, stack, alarmId: id);

      await tapVisible(
        tester,
        find.ancestor(
          of: find.text('On'),
          matching: find.byType(SwitchListTile),
        ),
      );
      await tester.tap(find.byKey(const Key('editor_save_button')));
      await pumpSettle(tester);

      final Alarm? stored = await stack.repository.getAlarmById(id);
      expect(stored?.enabled, isFalse);
      expect(stored?.nextTriggerAt, isNull);
      expect(stack.scheduler.cancelledIds, contains(id));
      await finishWidgetTest(tester, stack);
    });

    testWidgets('missing alarm shows the missing state',
        (WidgetTester tester) async {
      await pumpEditor(tester, stack, alarmId: 999);
      expect(find.text(en.msgAlarmMissing), findsOneWidget);
      expect(find.byKey(const Key('editor_save_button')), findsNothing);
      await finishWidgetTest(tester, stack);
    });
  });

  group('home round-trips', () {
    testWidgets('create flow returns home with confirmation',
        (WidgetTester tester) async {
      await pumpHome(tester, stack);
      await tester.tap(find.byKey(const Key('add_alarm_fab')));
      await pumpSettle(tester);
      await tester.enterText(
        find.byKey(const Key('editor_label_field')),
        'Round',
      );
      await tester.pump();
      await tester.tap(find.byKey(const Key('editor_save_button')));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.text(en.msgAlarmSaved), findsOneWidget);
      expect(find.text('Round'), findsOneWidget);
      await finishWidgetTest(tester, stack);
    });

    testWidgets('edit flow updates the home tile',
        (WidgetTester tester) async {
      final int id = await stack.insertAlarm(label: 'Before');
      await pumpHome(tester, stack);
      await tester.tap(find.byKey(Key('alarm_tile_$id')));
      await pumpSettle(tester);
      await tester.enterText(
        find.byKey(const Key('editor_label_field')),
        'After',
      );
      await tester.pump();
      await tester.tap(find.byKey(const Key('editor_save_button')));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.text(en.msgAlarmUpdated), findsOneWidget);
      expect(find.text('After'), findsOneWidget);
      expect(find.text('Before'), findsNothing);
      await finishWidgetTest(tester, stack);
    });

    testWidgets('back without saving creates nothing',
        (WidgetTester tester) async {
      await pumpHome(tester, stack);
      await tester.tap(find.byKey(const Key('add_alarm_fab')));
      await pumpSettle(tester);
      await tester.tap(find.byType(BackButton));
      await pumpSettle(tester);

      expect(await alarms(), isEmpty);
      expect(find.text(en.homeTitle), findsOneWidget);
      await finishWidgetTest(tester, stack);
    });
  });
}
