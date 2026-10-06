import 'package:alarmx/core/models/repeat_days.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Weekday', () {
    test('bit order matches the schema: bit 0 = Sunday .. bit 6 = Saturday',
        () {
      expect(Weekday.sunday.bit, 1);
      expect(Weekday.monday.bit, 2);
      expect(Weekday.tuesday.bit, 4);
      expect(Weekday.wednesday.bit, 8);
      expect(Weekday.thursday.bit, 16);
      expect(Weekday.friday.bit, 32);
      expect(Weekday.saturday.bit, 64);
    });
  });

  group('RepeatDays', () {
    test('empty and full selections', () {
      expect(RepeatDays.none.mask, 0);
      expect(RepeatDays.none.isEmpty, isTrue);
      expect(RepeatDays.none.isNotEmpty, isFalse);
      expect(RepeatDays.all.mask, 127);
      expect(RepeatDays.all.isNotEmpty, isTrue);
      expect(RepeatDays.all.days.length, 7);
    });

    test('weekday and weekend presets', () {
      expect(RepeatDays.weekdays.mask, 62);
      expect(RepeatDays.weekdays.has(Weekday.monday), isTrue);
      expect(RepeatDays.weekdays.has(Weekday.sunday), isFalse);
      expect(RepeatDays.weekend.mask, 65);
      expect(RepeatDays.weekend.days,
          <Weekday>{Weekday.sunday, Weekday.saturday});
    });

    test('fromDays and days round-trip through the mask', () {
      final RepeatDays selection = RepeatDays.fromDays(
        <Weekday>{Weekday.monday, Weekday.wednesday, Weekday.friday},
      );
      expect(selection.mask, 42);
      expect(selection.days,
          <Weekday>{Weekday.monday, Weekday.wednesday, Weekday.friday});
      expect(RepeatDays(selection.mask), selection);
    });

    test('add, remove, toggle and has', () {
      final RepeatDays added = RepeatDays.none.add(Weekday.tuesday);
      expect(added.has(Weekday.tuesday), isTrue);
      expect(added.mask, 4);

      final RepeatDays removed = added.remove(Weekday.tuesday);
      expect(removed, RepeatDays.none);

      final RepeatDays toggled = RepeatDays.none.toggle(Weekday.sunday);
      expect(toggled.has(Weekday.sunday), isTrue);
      expect(toggled.toggle(Weekday.sunday), RepeatDays.none);
    });

    test('equality is by mask value', () {
      expect(
        RepeatDays.fromDays(<Weekday>{Weekday.saturday}),
        const RepeatDays(64),
      );
      expect(const RepeatDays(1) == const RepeatDays(2), isFalse);
      expect(const RepeatDays(3).hashCode, const RepeatDays(3).hashCode);
    });
  });
}
