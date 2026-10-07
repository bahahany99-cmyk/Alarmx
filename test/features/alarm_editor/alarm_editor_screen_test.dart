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

  tearDown(() async {
    await stack.close();
  });

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
    });

    testWidgets('label entry is kept', (WidgetTester tester) async {
      await pumpEditor(tester, stack);
      await tester.enterText(
        find.byKey(const Key('editor_label_field')),
        'Gym',
      );
      await tester.pump();
      expect(find.text('Gym'), findsOneWidget);
    });

    testWidgets('once shows the date picker button',
        (WidgetTester tester) async {
      await pumpEditor(tester, stack);
      await tapVisible(tester, find.text(en.repeatOnce));
      expect(find.byKey(const Key('editor_date_button')), findsOneWidget);
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
    });
  });

  group('create save', () {
    testWidgets('daily alarm with label is saved and scheduled',
        (WidgetTester tester) async {
      debugPrint('PHASE daily-label: body start');
      await pumpEditor(tester, stack);
      debugPrint('PHASE daily-label: pumped');
      await tester.enterText(
        find.byKey(const Key('editor_label_field')),
        'Work',
      );
      debugPrint('PHASE daily-label: text entered');
      await tester.pump();
      debugPrint('PHASE daily-label: tapping save');
      await tester.tap(find.byKey(const Key('editor_save_button')));
      debugPrint('PHASE daily-label: save tapped, settling');
      await pumpSettle(tester);
      debugPrint('PHASE daily-label: settled');

      // Popped back.
      expect(find.byKey(const Key('editor_save_button')), findsNothing);
      final List<Alarm> rows = await alarms();
      expect(rows, hasLength(1));
      expect(rows.single.label, 'Work');
      expect(rows.single.hour, 7);
      expect(rows.single.repeatType, 'daily');
      expect(rows.single.nextTriggerAt, isNotNull);
      expect(stack.scheduler.scheduledIds, <int>[rows.single.id]);
      debugPrint('PHASE daily-label: body end');
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
    });

    testWidgets('mission section creates no mission rows',
        (WidgetTester tester) async {
      await pumpEditor(tester, stack);
      expect(find.text(en.missionTitle), findsOneWidget);
      await tester.tap(find.byKey(const Key('editor_save_button')));
      await pumpSettle(tester);

      expect(await missionRowCount(), 0);
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
    });

    testWidgets('missing alarm shows the missing state',
        (WidgetTester tester) async {
      await pumpEditor(tester, stack, alarmId: 999);
      expect(find.text(en.msgAlarmMissing), findsOneWidget);
      expect(find.byKey(const Key('editor_save_button')), findsNothing);
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
    });
  });
}
