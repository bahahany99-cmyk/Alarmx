import 'package:alarmx/core/database/database.dart';
import 'package:alarmx/core/l10n/app_strings.dart';
import 'package:alarmx/core/models/models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/test_doubles.dart';

// Home tests: real in-memory stack, English locale unless stated.

void main() {
  late TestStack stack;
  final AppStrings en = AppStrings.forCode('en');

  setUp(() {
    stack = TestStack();
  });

  tearDown(() async {
    await stack.close();
  });

  group('list rendering', () {
    testWidgets('empty state offers adding an alarm',
        (WidgetTester tester) async {
      await pumpHome(tester, stack);

      expect(find.text(en.homeTitle), findsOneWidget);
      expect(find.text(en.homeEmptyTitle), findsOneWidget);
      expect(find.text(en.homeEmptySubtitle), findsOneWidget);
      expect(find.byKey(const Key('empty_add_button')), findsOneWidget);
    });

    testWidgets('one alarm renders time, label, repeat and state',
        (WidgetTester tester) async {
      await stack.insertAlarm(hour: 6, minute: 0, label: 'Work');
      await pumpHome(tester, stack);

      expect(find.textContaining('6:00'), findsOneWidget);
      expect(find.text('Work'), findsOneWidget);
      expect(find.text('Daily'), findsOneWidget);
      expect(find.text('On'), findsOneWidget);
      expect(find.text('Not scheduled'), findsOneWidget);
    });

    testWidgets('multiple alarms all render', (WidgetTester tester) async {
      await stack.insertAlarm(hour: 6, minute: 0, label: 'First');
      await stack.insertAlarm(hour: 22, minute: 30, label: 'Second');
      await pumpHome(tester, stack);

      expect(find.text('First'), findsOneWidget);
      expect(find.text('Second'), findsOneWidget);
      expect(find.textContaining('6:00'), findsOneWidget);
      expect(find.textContaining('10:30'), findsOneWidget);
    });

    testWidgets('disabled alarm renders Off state', (WidgetTester tester) async {
      await stack.insertAlarm(hour: 6, label: 'Night', enabled: false);
      await pumpHome(tester, stack);

      expect(find.text('Off'), findsOneWidget);
      expect(find.text('On'), findsNothing);
    });

    testWidgets('scheduled alarm shows its next trigger',
        (WidgetTester tester) async {
      final int id =
          await stack.insertAlarm(hour: 7, minute: 30, label: 'Ring');
      await stack.coordinator.scheduleAlarm(id);
      await pumpHome(tester, stack);

      expect(find.textContaining('Next:'), findsOneWidget);
      expect(find.text('Not scheduled'), findsNothing);
    });
  });

  group('navigation', () {
    testWidgets('FAB opens the create screen', (WidgetTester tester) async {
      await pumpHome(tester, stack);
      await tester.tap(find.byKey(const Key('add_alarm_fab')));
      await tester.pumpAndSettle();

      expect(find.text(en.createAlarmTitle), findsOneWidget);
    });

    testWidgets('empty-state button opens the create screen',
        (WidgetTester tester) async {
      await pumpHome(tester, stack);
      await tester.tap(find.byKey(const Key('empty_add_button')));
      await tester.pumpAndSettle();

      expect(find.text(en.createAlarmTitle), findsOneWidget);
    });

    testWidgets('tapping an alarm opens the edit screen',
        (WidgetTester tester) async {
      final int id = await stack.insertAlarm(label: 'Work');
      await pumpHome(tester, stack);
      await tester.tap(find.byKey(Key('alarm_tile_$id')));
      await tester.pumpAndSettle();

      expect(find.text(en.editAlarmTitle), findsOneWidget);
      expect(find.text('Work'), findsOneWidget);
    });
  });

  group('enable/disable', () {
    testWidgets('toggle off disables and refreshes',
        (WidgetTester tester) async {
      final int id = await stack.insertAlarm(label: 'Work');
      await stack.coordinator.scheduleAlarm(id);
      await pumpHome(tester, stack);
      expect(find.text('On'), findsOneWidget);

      await tester.tap(find.byKey(Key('alarm_toggle_$id')));
      await tester.pumpAndSettle();

      expect(find.text('Off'), findsOneWidget);
      final Alarm? stored = await stack.repository.getAlarmById(id);
      expect(stored?.enabled, isFalse);
      expect(stored?.nextTriggerAt, isNull);
      expect(stack.scheduler.cancelledIds, contains(id));
    });

    testWidgets('toggle on enables and schedules',
        (WidgetTester tester) async {
      final int id = await stack.insertAlarm(label: 'Work', enabled: false);
      await pumpHome(tester, stack);

      await tester.tap(find.byKey(Key('alarm_toggle_$id')));
      await tester.pumpAndSettle();

      expect(find.text('On'), findsOneWidget);
      expect(stack.scheduler.scheduledIds, <int>[id]);
      final Alarm? stored = await stack.repository.getAlarmById(id);
      expect(stored?.enabled, isTrue);
      expect(stored?.nextTriggerAt, isNotNull);
    });

    testWidgets('toggle failure shows an error message',
        (WidgetTester tester) async {
      stack.scheduler.canSchedule = false;
      final int id = await stack.insertAlarm(label: 'Work', enabled: false);
      await pumpHome(tester, stack);

      await tester.tap(find.byKey(Key('alarm_toggle_$id')));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.text(en.msgNoPermission), findsOneWidget);
      // Desired state is kept even though scheduling failed.
      expect((await stack.repository.getAlarmById(id))?.enabled, isTrue);
    });
  });

  group('delete', () {
    testWidgets('cancel keeps the alarm', (WidgetTester tester) async {
      final int id = await stack.insertAlarm(label: 'Work');
      await pumpHome(tester, stack);

      await tester.tap(find.byKey(Key('alarm_delete_$id')));
      await tester.pumpAndSettle();
      expect(find.text(en.deleteTitle), findsOneWidget);

      await tester.tap(find.text(en.cancel));
      await tester.pumpAndSettle();

      expect(await stack.repository.getAlarmById(id), isNotNull);
      expect(find.text('Work'), findsOneWidget);
    });

    testWidgets('confirm cancels the schedule and deletes the row',
        (WidgetTester tester) async {
      final int id = await stack.insertAlarm(label: 'Work');
      await stack.coordinator.scheduleAlarm(id);
      await pumpHome(tester, stack);

      await tester.tap(find.byKey(Key('alarm_delete_$id')));
      await tester.pumpAndSettle();
      await tester.tap(find.text(en.delete));
      await tester.pumpAndSettle();

      expect(stack.scheduler.cancelledIds, contains(id));
      expect(await stack.repository.getAlarmById(id), isNull);
      expect(find.text('Work'), findsNothing);
      expect(find.text(en.homeEmptyTitle), findsOneWidget);
    });

    testWidgets('delete failure is reported and keeps the row',
        (WidgetTester tester) async {
      stack.scheduler.cancelError = StateError('bridge down');
      final int id = await stack.insertAlarm(label: 'Work');
      await pumpHome(tester, stack);

      await tester.tap(find.byKey(Key('alarm_delete_$id')));
      await tester.pumpAndSettle();
      await tester.tap(find.text(en.delete));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.text(en.msgDeleteFailed), findsOneWidget);
      expect(await stack.repository.getAlarmById(id), isNotNull);
    });
  });

  group('language', () {
    testWidgets('menu reports the selected language',
        (WidgetTester tester) async {
      final List<String> selected = <String>[];
      await pumpHome(
        tester,
        stack,
        onLanguageChanged: selected.add,
      );

      await tester.tap(find.byIcon(Icons.language));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Arabic'));
      await tester.pumpAndSettle();

      expect(selected, <String>['ar']);
    });

    testWidgets('Arabic locale renders RTL Arabic UI',
        (WidgetTester tester) async {
      await stack.insertAlarm(
        repeatType: RepeatType.custom,
        repeatDays: RepeatDays.fromDays(
          {Weekday.sunday, Weekday.monday},
        ).mask,
      );
      await pumpHome(tester, stack, language: 'ar');

      final AppStrings ar = AppStrings.forCode('ar');
      expect(find.text(ar.homeTitle), findsOneWidget);
      expect(find.text('الأحد، الاثنين'), findsOneWidget);
      final Directionality directionality =
          tester.widget(find.byType(Directionality).first);
      expect(directionality.textDirection, TextDirection.rtl);
    });
  });
}
