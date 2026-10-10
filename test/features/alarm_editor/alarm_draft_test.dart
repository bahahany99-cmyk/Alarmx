import 'package:alarmx/core/database/database.dart';
import 'package:alarmx/core/models/models.dart';
import 'package:alarmx/features/alarm_editor/alarm_draft.dart';
import 'package:flutter/material.dart' show TimeOfDay;
import 'package:flutter_test/flutter_test.dart';

Alarm _alarm({
  int id = 1,
  String? label,
  int hour = 7,
  int minute = 30,
  bool enabled = true,
  String repeatType = 'daily',
  int? repeatDays,
  DateTime? onceDate,
  String? soundUri,
  String soundType = 'default',
  int volume = 80,
  bool fadeInEnabled = false,
  bool vibrationEnabled = true,
  bool snoozeEnabled = true,
  int snoozeMinutes = 5,
  int snoozeMaxCount = 3,
  bool strictMode = false,
  DateTime? nextTriggerAt,
}) {
  final DateTime now = DateTime(2026, 10, 5, 10, 0);
  return Alarm(
    id: id,
    label: label,
    hour: hour,
    minute: minute,
    enabled: enabled,
    repeatType: repeatType,
    repeatDays: repeatDays,
    onceDate: onceDate,
    soundUri: soundUri,
    soundType: soundType,
    volume: volume,
    fadeInEnabled: fadeInEnabled,
    vibrationEnabled: vibrationEnabled,
    snoozeEnabled: snoozeEnabled,
    snoozeMinutes: snoozeMinutes,
    snoozeMaxCount: snoozeMaxCount,
    strictMode: strictMode,
    nextTriggerAt: nextTriggerAt,
    createdAt: now,
    updatedAt: now,
  );
}

void main() {
  final DateTime monday = DateTime(2026, 10, 5, 15, 30);

  group('AlarmDraft defaults', () {
    test('new alarm defaults to 07:00 daily enabled', () {
      final AlarmDraft draft = AlarmDraft(now: monday);
      expect(draft.hour, 7);
      expect(draft.minute, 0);
      expect(draft.label, '');
      expect(draft.enabled, isTrue);
      expect(draft.repeatType, RepeatType.daily);
    });

    test('default one-time date is the pinned today', () {
      final AlarmDraft draft = AlarmDraft(now: monday);
      expect(draft.onceDate, DateTime(2026, 10, 5));
    });

    test('sound/vibration/snooze defaults match schema', () {
      final AlarmDraft draft = AlarmDraft(now: monday);
      expect(draft.soundType, kDefaultSoundType);
      expect(draft.soundUri, '');
      expect(draft.volume, 80);
      expect(draft.vibrationEnabled, isTrue);
      expect(draft.fadeInEnabled, isFalse);
      expect(draft.snoozeEnabled, isTrue);
      expect(draft.snoozeMinutes, 5);
      expect(draft.snoozeMaxCount, 3);
      expect(draft.strictMode, isFalse);
    });
  });

  group('AlarmDraft.fromAlarm', () {
    test('carries every editable field', () {
      final AlarmDraft draft = AlarmDraft.fromAlarm(
        _alarm(
          label: 'Work',
          hour: 6,
          minute: 15,
          enabled: false,
          repeatType: 'custom',
          repeatDays: 10,
          soundUri: 'content://x',
          soundType: 'custom',
          volume: 42,
          fadeInEnabled: true,
          vibrationEnabled: false,
          snoozeEnabled: false,
          snoozeMinutes: 15,
          snoozeMaxCount: 2,
          strictMode: true,
        ),
        now: monday,
      );
      expect(draft.label, 'Work');
      expect(draft.hour, 6);
      expect(draft.minute, 15);
      expect(draft.enabled, isFalse);
      expect(draft.repeatType, RepeatType.custom);
      expect(draft.repeatDays, const RepeatDays(10));
      expect(draft.soundUri, 'content://x');
      expect(draft.soundType, 'custom');
      expect(draft.volume, 42);
      expect(draft.fadeInEnabled, isTrue);
      expect(draft.vibrationEnabled, isFalse);
      expect(draft.snoozeEnabled, isFalse);
      expect(draft.snoozeMinutes, 15);
      expect(draft.snoozeMaxCount, 2);
      expect(draft.strictMode, isTrue);
    });

    test('unknown repeat type falls back to once', () {
      final AlarmDraft draft = AlarmDraft.fromAlarm(
        _alarm(repeatType: 'yearly'),
        now: monday,
      );
      expect(draft.repeatType, RepeatType.once);
    });

    test('oversized day mask is masked to 7 bits', () {
      final AlarmDraft draft = AlarmDraft.fromAlarm(
        _alarm(repeatType: 'custom', repeatDays: 255),
        now: monday,
      );
      expect(draft.repeatDays, RepeatDays.all);
    });

    test('out-of-range hour/minute are clamped', () {
      final AlarmDraft draft = AlarmDraft.fromAlarm(
        _alarm(hour: 99, minute: -5),
        now: monday,
      );
      expect(draft.hour, 23);
      expect(draft.minute, 0);
    });

    test('missing one-time date becomes today', () {
      final AlarmDraft draft = AlarmDraft.fromAlarm(
        _alarm(repeatType: 'once', onceDate: null),
        now: monday,
      );
      expect(draft.onceDate, DateTime(2026, 10, 5));
    });
  });

  group('AlarmDraft time', () {
    test('getter exposes TimeOfDay', () {
      final AlarmDraft draft = AlarmDraft(now: monday);
      expect(draft.time, const TimeOfDay(hour: 7, minute: 0));
    });

    test('setter stores hour/minute', () {
      final AlarmDraft draft = AlarmDraft(now: monday);
      draft.time = const TimeOfDay(hour: 22, minute: 45);
      expect(draft.hour, 22);
      expect(draft.minute, 45);
    });
  });

  group('AlarmDraft custom sound', () {
    test('enabling marks custom and keeps the URI', () {
      final AlarmDraft draft = AlarmDraft(now: monday);
      draft.setCustomSound(true);
      draft.soundUri = 'content://x';
      expect(draft.isCustomSound, isTrue);
      expect(draft.soundType, kCustomSoundType);
    });

    test('disabling restores default and clears the URI', () {
      final AlarmDraft draft = AlarmDraft(now: monday);
      draft.setCustomSound(true);
      draft.soundUri = 'content://x';
      draft.setCustomSound(false);
      expect(draft.isCustomSound, isFalse);
      expect(draft.soundType, kDefaultSoundType);
      expect(draft.soundUri, '');
    });
  });

  group('AlarmDraft validation', () {
    test('daily is always structurally valid', () {
      final AlarmDraft daily = AlarmDraft(now: monday);
      expect(daily.validationMessageKey(now: monday), isNull);
    });

    test('once with a future occurrence is valid', () {
      final AlarmDraft once = AlarmDraft(now: monday)
        ..repeatType = RepeatType.once
        ..hour = 18
        ..minute = 0;
      // Monday 18:00 is after the pinned Monday 15:30.
      expect(once.validationMessageKey(now: monday), isNull);
    });

    test('once with a past occurrence is rejected', () {
      final AlarmDraft once = AlarmDraft(now: monday)
        ..repeatType = RepeatType.once;
      // Default 07:00 on the pinned Monday is already past at 15:30.
      expect(once.validationMessageKey(now: monday), 'msgOnceInPast');
    });

    test('once exactly at now is rejected', () {
      final AlarmDraft once = AlarmDraft(now: monday)
        ..repeatType = RepeatType.once
        ..hour = 15
        ..minute = 30;
      expect(once.validationMessageKey(now: monday), 'msgOnceInPast');
    });

    test('custom with no day is rejected', () {
      final AlarmDraft draft = AlarmDraft(now: monday)
        ..repeatType = RepeatType.custom;
      expect(draft.validationMessageKey(), 'msgValidationDays');
    });

    test('custom with a day is valid', () {
      final AlarmDraft draft = AlarmDraft(now: monday)
        ..repeatType = RepeatType.custom
        ..repeatDays = RepeatDays.fromDays({Weekday.monday});
      expect(draft.validationMessageKey(), isNull);
    });
  });

  group('AlarmDraft.nextOccurrence', () {
    test('daily delegates to the shared calculator', () {
      final AlarmDraft draft = AlarmDraft(now: monday);
      expect(
        draft.nextOccurrence(now: monday),
        DateTime(2026, 10, 6, 7, 0),
      );
    });

    test('once resolves to its configured day', () {
      final AlarmDraft draft = AlarmDraft(now: monday)
        ..repeatType = RepeatType.once
        ..hour = 18
        ..minute = 45;
      expect(
        draft.nextOccurrence(now: monday),
        DateTime(2026, 10, 5, 18, 45),
      );
    });

    test('past once has no occurrence', () {
      final AlarmDraft draft = AlarmDraft(now: monday)
        ..repeatType = RepeatType.once;
      expect(draft.nextOccurrence(now: monday), isNull);
    });

    test('atTime previews a candidate wheel position', () {
      final AlarmDraft draft = AlarmDraft(now: monday);
      expect(
        draft.nextOccurrence(
          now: monday,
          atTime: const TimeOfDay(hour: 20, minute: 15),
        ),
        DateTime(2026, 10, 5, 20, 15),
      );
      // The draft itself is untouched by the preview.
      expect(draft.hour, 7);
      expect(draft.minute, 0);
    });
  });

  group('formatRemainingDuration', () {
    test('english compacts to the largest two units', () {
      expect(
        formatRemainingDuration(const Duration(hours: 7, minutes: 25), 'en'),
        '7h 25m',
      );
      expect(
        formatRemainingDuration(const Duration(days: 3, hours: 4), 'en'),
        '3d 4h',
      );
      expect(
        formatRemainingDuration(const Duration(minutes: 35), 'en'),
        '35m',
      );
    });

    test('arabic uses arabic unit glyphs', () {
      expect(
        formatRemainingDuration(const Duration(hours: 7, minutes: 25), 'ar'),
        '7\u0633 25\u062f',
      );
      expect(
        formatRemainingDuration(const Duration(days: 2, hours: 5), 'ar'),
        '2 \u064a\u0648\u0645 5\u0633',
      );
    });

    test('negative durations clamp to zero', () {
      expect(
        formatRemainingDuration(const Duration(minutes: -5), 'en'),
        '0m',
      );
    });
  });

  group('AlarmDraft.toCompanion', () {
    test('daily writes null repeatDays/onceDate', () {
      final AlarmsCompanion companion =
          AlarmDraft(now: monday).toCompanion();
      expect(companion.hour.value, 7);
      expect(companion.minute.value, 0);
      expect(companion.enabled.value, isTrue);
      expect(companion.repeatType.value, 'daily');
      expect(companion.repeatDays.value, isNull);
      expect(companion.onceDate.value, isNull);
      expect(companion.nextTriggerAt.present, isFalse);
    });

    test('custom writes the mask, once writes the date', () {
      final AlarmDraft custom = AlarmDraft(now: monday)
        ..repeatType = RepeatType.custom
        ..repeatDays = RepeatDays.fromDays({Weekday.monday});
      expect(custom.toCompanion().repeatDays.value, 2);

      final AlarmDraft once = AlarmDraft(now: monday)
        ..repeatType = RepeatType.once;
      final AlarmsCompanion companion = once.toCompanion();
      expect(companion.onceDate.value, DateTime(2026, 10, 5));
      expect(companion.repeatDays.value, isNull);
    });

    test('empty label and URI become null; empty URI forces default', () {
      final AlarmDraft draft = AlarmDraft(now: monday)
        ..label = '   '
        ..setCustomSound(true);
      final AlarmsCompanion companion = draft.toCompanion();
      expect(companion.label.value, isNull);
      expect(companion.soundUri.value, isNull);
      expect(companion.soundType.value, kDefaultSoundType);
    });

    test('label is trimmed, custom URI kept with custom type', () {
      final AlarmDraft draft = AlarmDraft(now: monday)
        ..label = '  Work  '
        ..setCustomSound(true)
        ..soundUri = 'content://x';
      final AlarmsCompanion companion = draft.toCompanion();
      expect(companion.label.value, 'Work');
      expect(companion.soundUri.value, 'content://x');
      expect(companion.soundType.value, kCustomSoundType);
    });
  });

  group('AlarmDraft.applyTo', () {
    test('preserves id, stored trigger and createdAt', () {
      final DateTime trigger = DateTime(2026, 10, 6, 7, 0);
      final Alarm original = _alarm(id: 7, nextTriggerAt: trigger);
      final Alarm updated = AlarmDraft(now: monday).applyTo(original);
      expect(updated.id, 7);
      expect(updated.nextTriggerAt, trigger);
      expect(updated.createdAt, original.createdAt);
    });

    test('applies edits and clears the mask when leaving custom', () {
      final Alarm original = _alarm(
        repeatType: 'custom',
        repeatDays: 62,
      );
      final AlarmDraft draft = AlarmDraft.fromAlarm(original, now: monday)
        ..label = 'New'
        ..hour = 8
        ..repeatType = RepeatType.daily;
      final Alarm updated = draft.applyTo(original);
      expect(updated.label, 'New');
      expect(updated.hour, 8);
      expect(updated.repeatType, 'daily');
      expect(updated.repeatDays, isNull);
    });
  });
}
