import 'package:alarmx/core/database/database.dart';
import 'package:alarmx/core/l10n/app_strings.dart';
import 'package:alarmx/core/models/models.dart';
import 'package:alarmx/features/home/alarm_formatters.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/test_doubles.dart';

Alarm _alarm({
  int hour = 7,
  int minute = 30,
  bool enabled = true,
  String repeatType = 'daily',
  int? repeatDays,
  DateTime? onceDate,
  DateTime? nextTriggerAt,
}) {
  final DateTime now = DateTime(2026, 10, 5, 10, 0);
  return Alarm(
    id: 1,
    label: null,
    hour: hour,
    minute: minute,
    enabled: enabled,
    repeatType: repeatType,
    repeatDays: repeatDays,
    onceDate: onceDate,
    soundUri: null,
    soundType: 'default',
    volume: 80,
    fadeInEnabled: false,
    vibrationEnabled: true,
    snoozeEnabled: true,
    snoozeMinutes: 5,
    snoozeMaxCount: 3,
    strictMode: false,
    nextTriggerAt: nextTriggerAt,
    createdAt: now,
    updatedAt: now,
  );
}

/// Normalizes time-period spacing across SDK versions (some format
/// "7:30 AM" with a narrow no-break space instead of a plain space).
String _spaces(String text) => text.replaceAll('\u2009', ' ');

/// Runs [format] with a [BuildContext] in [language].
Future<String> _formatIn(
  WidgetTester tester,
  String language,
  String Function(BuildContext context) format,
) async {
  late final String result;
  await tester.pumpWidget(
    MaterialApp(
      locale: Locale(language),
      supportedLocales: testLocales,
      localizationsDelegates: testDelegates,
      home: Builder(
        builder: (BuildContext context) {
          result = format(context);
          return const SizedBox();
        },
      ),
    ),
  );
  return result;
}

void main() {
  group('formatAlarmTime', () {
    testWidgets('formats in English', (WidgetTester tester) async {
      final String text = await _formatIn(
        tester,
        'en',
        (BuildContext context) => formatAlarmTime(context, 7, 30),
      );
      expect(_spaces(text), '7:30 AM');
    });

    testWidgets('clamps garbage hour/minute', (WidgetTester tester) async {
      final String text = await _formatIn(
        tester,
        'en',
        (BuildContext context) => formatAlarmTime(context, 99, -5),
      );
      expect(_spaces(text), '11:00 PM');
    });

    testWidgets('differs in Arabic', (WidgetTester tester) async {
      final String text = await _formatIn(
        tester,
        'ar',
        (BuildContext context) => formatAlarmTime(context, 7, 30),
      );
      expect(_spaces(text), isNot('7:30 AM'));
      expect(text, isNotEmpty);
    });
  });

  group('describeRepeat', () {
    testWidgets('daily', (WidgetTester tester) async {
      final String text = await _formatIn(
        tester,
        'en',
        (BuildContext context) => describeRepeat(context, _alarm()),
      );
      expect(text, 'Daily');
    });

    testWidgets('once renders the stored date', (WidgetTester tester) async {
      final String text = await _formatIn(
        tester,
        'en',
        (BuildContext context) => describeRepeat(
          context,
          _alarm(
            repeatType: 'once',
            onceDate: DateTime(2026, 10, 8),
          ),
        ),
      );
      expect(text, 'Thu, Oct 8');
    });

    testWidgets('dateless once falls back to the label',
        (WidgetTester tester) async {
      final String text = await _formatIn(
        tester,
        'en',
        (BuildContext context) => describeRepeat(
          context,
          _alarm(repeatType: 'once'),
        ),
      );
      expect(text, 'Once');
    });

    testWidgets('custom joins day names', (WidgetTester tester) async {
      final String text = await _formatIn(
        tester,
        'en',
        (BuildContext context) => describeRepeat(
          context,
          _alarm(
            repeatType: 'custom',
            repeatDays: RepeatDays.fromDays(
              {Weekday.monday, Weekday.wednesday},
            ).mask,
          ),
        ),
      );
      expect(text, 'Mon, Wed');
    });

    testWidgets('custom joins Arabic day names with Arabic separator',
        (WidgetTester tester) async {
      final String text = await _formatIn(
        tester,
        'ar',
        (BuildContext context) => describeRepeat(
          context,
          _alarm(
            repeatType: 'custom',
            repeatDays: RepeatDays.fromDays(
              {Weekday.sunday, Weekday.monday},
            ).mask,
          ),
        ),
      );
      expect(text, 'الأحد، الاثنين');
    });

    testWidgets('empty custom falls back to the label',
        (WidgetTester tester) async {
      final String text = await _formatIn(
        tester,
        'en',
        (BuildContext context) => describeRepeat(
          context,
          _alarm(repeatType: 'custom', repeatDays: 0),
        ),
      );
      expect(text, 'Custom');
    });
  });

  group('describeNextTrigger', () {
    testWidgets('renders the stored trigger verbatim',
        (WidgetTester tester) async {
      final String text = await _formatIn(
        tester,
        'en',
        (BuildContext context) => describeNextTrigger(
          context,
          _alarm(nextTriggerAt: DateTime(2026, 10, 6, 7, 30)),
        ),
      );
      expect(_spaces(text), 'Next: Tue, Oct 6 7:30 AM');
    });

    testWidgets('disabled or triggerless alarms show not-scheduled',
        (WidgetTester tester) async {
      final String disabled = await _formatIn(
        tester,
        'en',
        (BuildContext context) => describeNextTrigger(
          context,
          _alarm(enabled: false, nextTriggerAt: DateTime(2026, 10, 6)),
        ),
      );
      expect(disabled, 'Not scheduled');

      final String triggerless = await _formatIn(
        tester,
        'en',
        (BuildContext context) => describeNextTrigger(context, _alarm()),
      );
      expect(triggerless, 'Not scheduled');
    });
  });

  group('weekdayName', () {
    test('covers every weekday in both languages', () {
      final AppStrings ar = AppStrings.forCode('ar');
      final AppStrings en = AppStrings.forCode('en');
      for (final Weekday day in Weekday.values) {
        expect(weekdayName(ar, day), isNotEmpty);
        expect(weekdayName(en, day), isNotEmpty);
      }
      expect(weekdayName(en, Weekday.friday), 'Fri');
      expect(weekdayName(ar, Weekday.saturday), 'السبت');
    });
  });
}
