import 'package:alarmx/core/models/models.dart';
import 'package:alarmx/core/scheduling/alarm_schedule.dart';
import 'package:alarmx/core/scheduling/next_occurrence_calculator.dart';
import 'package:flutter_test/flutter_test.dart';

// Pure unit tests: fixed reference times, no database, no native code.
// Reference week (local time): Mon 2026-10-05 .. Sun 2026-10-11.

void main() {
  const NextOccurrenceCalculator calculator = NextOccurrenceCalculator();

  group('Weekday.fromDateTime', () {
    test('maps every dart weekday', () {
      expect(Weekday.fromDateTime(DateTime(2026, 10, 4)), Weekday.sunday);
      expect(Weekday.fromDateTime(DateTime(2026, 10, 5)), Weekday.monday);
      expect(Weekday.fromDateTime(DateTime(2026, 10, 6)), Weekday.tuesday);
      expect(Weekday.fromDateTime(DateTime(2026, 10, 7)), Weekday.wednesday);
      expect(Weekday.fromDateTime(DateTime(2026, 10, 8)), Weekday.thursday);
      expect(Weekday.fromDateTime(DateTime(2026, 10, 9)), Weekday.friday);
      expect(Weekday.fromDateTime(DateTime(2026, 10, 10)), Weekday.saturday);
    });
  });

  group('one-time', () {
    test('future date returns that day at hour:minute', () {
      final DateTime? next = calculator.nextOccurrence(
        schedule: AlarmSchedule(
          repeatType: RepeatType.once,
          hour: 7,
          minute: 30,
          onceDate: DateTime(2026, 10, 7),
        ),
        now: DateTime(2026, 10, 5, 10, 0),
      );
      expect(next, DateTime(2026, 10, 7, 7, 30));
    });

    test('same-day future time returns today', () {
      final DateTime? next = calculator.nextOccurrence(
        schedule: AlarmSchedule(
          repeatType: RepeatType.once,
          hour: 12,
          minute: 0,
          onceDate: DateTime(2026, 10, 5),
        ),
        now: DateTime(2026, 10, 5, 10, 0),
      );
      expect(next, DateTime(2026, 10, 5, 12, 0));
    });

    test('past occurrence returns null', () {
      final DateTime? next = calculator.nextOccurrence(
        schedule: AlarmSchedule(
          repeatType: RepeatType.once,
          hour: 7,
          minute: 30,
          onceDate: DateTime(2026, 10, 5),
        ),
        now: DateTime(2026, 10, 5, 10, 0),
      );
      expect(next, isNull);
    });

    test('exactly now returns null (must be strictly in the future)', () {
      final DateTime? next = calculator.nextOccurrence(
        schedule: AlarmSchedule(
          repeatType: RepeatType.once,
          hour: 10,
          minute: 0,
          onceDate: DateTime(2026, 10, 5),
        ),
        now: DateTime(2026, 10, 5, 10, 0),
      );
      expect(next, isNull);
    });

    test('missing date returns null', () {
      final DateTime? next = calculator.nextOccurrence(
        schedule: const AlarmSchedule(
          repeatType: RepeatType.once,
          hour: 7,
          minute: 30,
        ),
        now: DateTime(2026, 10, 5, 10, 0),
      );
      expect(next, isNull);
    });

    test('time component carried by onceDate is ignored', () {
      final DateTime? next = calculator.nextOccurrence(
        schedule: AlarmSchedule(
          repeatType: RepeatType.once,
          hour: 7,
          minute: 30,
          onceDate: DateTime(2026, 10, 7, 23, 59),
        ),
        now: DateTime(2026, 10, 5, 10, 0),
      );
      expect(next, DateTime(2026, 10, 7, 7, 30));
    });
  });

  group('daily', () {
    test('later today returns today', () {
      final DateTime? next = calculator.nextOccurrence(
        schedule: const AlarmSchedule(
          repeatType: RepeatType.daily,
          hour: 12,
          minute: 0,
        ),
        now: DateTime(2026, 10, 5, 10, 0),
      );
      expect(next, DateTime(2026, 10, 5, 12, 0));
    });

    test('earlier today returns tomorrow', () {
      final DateTime? next = calculator.nextOccurrence(
        schedule: const AlarmSchedule(
          repeatType: RepeatType.daily,
          hour: 7,
          minute: 30,
        ),
        now: DateTime(2026, 10, 5, 10, 0),
      );
      expect(next, DateTime(2026, 10, 6, 7, 30));
    });

    test('exactly now returns tomorrow', () {
      final DateTime? next = calculator.nextOccurrence(
        schedule: const AlarmSchedule(
          repeatType: RepeatType.daily,
          hour: 10,
          minute: 0,
        ),
        now: DateTime(2026, 10, 5, 10, 0),
      );
      expect(next, DateTime(2026, 10, 6, 10, 0));
    });

    test('rolls over month boundary', () {
      final DateTime? next = calculator.nextOccurrence(
        schedule: const AlarmSchedule(
          repeatType: RepeatType.daily,
          hour: 7,
          minute: 30,
        ),
        now: DateTime(2026, 10, 31, 23, 0),
      );
      expect(next, DateTime(2026, 11, 1, 7, 30));
    });

    test('midnight alarm after noon returns tomorrow midnight', () {
      final DateTime? next = calculator.nextOccurrence(
        schedule: const AlarmSchedule(
          repeatType: RepeatType.daily,
          hour: 0,
          minute: 0,
        ),
        now: DateTime(2026, 10, 5, 12, 0),
      );
      expect(next, DateTime(2026, 10, 6, 0, 0));
    });
  });

  group('selected weekdays', () {
    test('today selected and in the future returns today', () {
      final DateTime? next = calculator.nextOccurrence(
        schedule: AlarmSchedule(
          repeatType: RepeatType.custom,
          hour: 12,
          minute: 0,
          repeatDays: RepeatDays.fromDays(
            <Weekday>{Weekday.monday, Weekday.wednesday},
          ),
        ),
        now: DateTime(2026, 10, 5, 10, 0),
      );
      expect(next, DateTime(2026, 10, 5, 12, 0));
    });

    test('today selected but passed returns the next selected day', () {
      final DateTime? next = calculator.nextOccurrence(
        schedule: AlarmSchedule(
          repeatType: RepeatType.custom,
          hour: 7,
          minute: 30,
          repeatDays: RepeatDays.fromDays(
            <Weekday>{Weekday.monday, Weekday.wednesday},
          ),
        ),
        now: DateTime(2026, 10, 5, 10, 0),
      );
      expect(next, DateTime(2026, 10, 7, 7, 30));
    });

    test('only today selected and passed returns same day next week', () {
      final DateTime? next = calculator.nextOccurrence(
        schedule: AlarmSchedule(
          repeatType: RepeatType.custom,
          hour: 7,
          minute: 30,
          repeatDays: RepeatDays.fromDays(<Weekday>{Weekday.monday}),
        ),
        now: DateTime(2026, 10, 5, 10, 0),
      );
      expect(next, DateTime(2026, 10, 12, 7, 30));
    });

    test('rolls across the weekend', () {
      final DateTime? next = calculator.nextOccurrence(
        schedule: AlarmSchedule(
          repeatType: RepeatType.custom,
          hour: 7,
          minute: 30,
          repeatDays: RepeatDays.fromDays(<Weekday>{Weekday.monday}),
        ),
        now: DateTime(2026, 10, 9, 18, 0),
      );
      expect(next, DateTime(2026, 10, 12, 7, 30));
    });

    test('sunday selection works on both sides of midnight', () {
      final AlarmSchedule sundayMorning = AlarmSchedule(
        repeatType: RepeatType.custom,
        hour: 9,
        minute: 0,
        repeatDays: RepeatDays.fromDays(<Weekday>{Weekday.sunday}),
      );
      expect(
        calculator.nextOccurrence(
          schedule: sundayMorning,
          now: DateTime(2026, 10, 4, 8, 0),
        ),
        DateTime(2026, 10, 4, 9, 0),
      );
      expect(
        calculator.nextOccurrence(
          schedule: sundayMorning,
          now: DateTime(2026, 10, 4, 10, 0),
        ),
        DateTime(2026, 10, 11, 9, 0),
      );
    });

    test('all days with today passed returns tomorrow', () {
      final DateTime? next = calculator.nextOccurrence(
        schedule: const AlarmSchedule(
          repeatType: RepeatType.custom,
          hour: 7,
          minute: 30,
          repeatDays: RepeatDays.all,
        ),
        now: DateTime(2026, 10, 5, 10, 0),
      );
      expect(next, DateTime(2026, 10, 6, 7, 30));
    });

    test('no day selected returns null', () {
      final DateTime? next = calculator.nextOccurrence(
        schedule: const AlarmSchedule(
          repeatType: RepeatType.custom,
          hour: 7,
          minute: 30,
        ),
        now: DateTime(2026, 10, 5, 10, 0),
      );
      expect(next, isNull);
    });

    test('rolls over month boundary', () {
      final DateTime? next = calculator.nextOccurrence(
        schedule: AlarmSchedule(
          repeatType: RepeatType.custom,
          hour: 9,
          minute: 0,
          repeatDays: RepeatDays.fromDays(<Weekday>{Weekday.sunday}),
        ),
        now: DateTime(2026, 10, 31, 10, 0),
      );
      expect(next, DateTime(2026, 11, 1, 9, 0));
    });
  });
}
