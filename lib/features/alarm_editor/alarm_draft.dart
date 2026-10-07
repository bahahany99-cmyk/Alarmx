// Mutable form state for the create/edit alarm screen (Phase 3).
//
// The Drift `Alarm` row is immutable, so the editor edits an [AlarmDraft]
// and converts it at save time: [toCompanion] for inserts,
// [applyTo] for updates. The draft owns structural input validation only
// ([validationMessageKey]); whether the alarm actually has an upcoming
// occurrence stays the coordinator/calculator's job — the UI never
// duplicates recurrence or trigger-time math.
//
// Conventions:
//   - `repeatDays` is meaningful only when `repeatType` is custom; the
//     conversion writes null otherwise (matching the schema docs).
//   - `onceDate` is meaningful only when `repeatType` is once.
//   - `strictMode` has no editor control in this phase (see below) and is
//     only carried through so create/edit preserve it.
//   - A past one-time date/time is NOT a validation error here: the
//     coordinator reports it via `AlarmNotSchedulable` and the UI shows
//     that outcome. "Past" depends on schedule time, not form structure.
//   - `soundType` 'default' vs 'custom': 'custom' is written only together
//     with a non-empty `soundUri`. The native service does not consume
//     either yet (default ringtone pipeline); both are stored config for
//     the later audio phase.

import 'package:alarmx/core/database/database.dart';
import 'package:alarmx/core/models/models.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart' show TimeOfDay;

/// Stored `soundType` meaning "play the system default alarm ringtone".
const String kDefaultSoundType = 'default';

/// Stored `soundType` meaning "a custom URI was configured".
///
/// Written only together with a non-empty `soundUri`. Vocabulary for the
/// later audio phase; the current native service ignores both fields.
const String kCustomSoundType = 'custom';

/// Fixed snooze-length options (minutes). Fixed choices keep the stored
/// values inside a sane range without free-form numeric input.
const List<int> kSnoozeMinuteOptions = <int>[5, 10, 15, 20, 30];

/// Fixed maximum-snooze-count options.
const List<int> kSnoozeMaxCountOptions = <int>[1, 2, 3, 5];

/// Editable alarm form state; see the file docs.
class AlarmDraft {
  /// Draft for a new alarm. [now] pins "today" for the default one-time
  /// date (defaults to the current day; tests pass an explicit value).
  AlarmDraft({DateTime? now})
      : onceDate = _dateOnly(now ?? DateTime.now());

  /// Draft initialized from a stored alarm for editing.
  ///
  /// Defensive clamps keep legacy/garbage rows renderable: unknown repeat
  /// types fall back via [RepeatType.fromDbValue], the day mask is masked
  /// to 7 bits, hour/minute are clamped to their valid ranges, and a
  /// missing one-time date becomes today.
  AlarmDraft.fromAlarm(Alarm alarm, {DateTime? now})
      : hour = alarm.hour.clamp(0, 23),
        minute = alarm.minute.clamp(0, 59),
        label = alarm.label ?? '',
        enabled = alarm.enabled,
        repeatType = RepeatType.fromDbValue(alarm.repeatType),
        onceDate = alarm.onceDate != null
            ? _dateOnly(alarm.onceDate!)
            : _dateOnly(now ?? DateTime.now()),
        repeatDays = RepeatDays((alarm.repeatDays ?? 0) & 127),
        soundType = alarm.soundType,
        soundUri = alarm.soundUri ?? '',
        volume = alarm.volume.clamp(0, 100),
        fadeInEnabled = alarm.fadeInEnabled,
        vibrationEnabled = alarm.vibrationEnabled,
        snoozeEnabled = alarm.snoozeEnabled,
        snoozeMinutes = alarm.snoozeMinutes,
        snoozeMaxCount = alarm.snoozeMaxCount,
        strictMode = alarm.strictMode;

  int hour = 7;
  int minute = 0;
  String label = '';
  bool enabled = true;
  RepeatType repeatType = RepeatType.daily;
  DateTime onceDate;
  RepeatDays repeatDays = RepeatDays.none;
  String soundType = kDefaultSoundType;
  String soundUri = '';
  int volume = 80;
  bool fadeInEnabled = false;
  bool vibrationEnabled = true;
  bool snoozeEnabled = true;
  int snoozeMinutes = 5;
  int snoozeMaxCount = 3;

  /// Carried through create/edit without an editor control. Strict Mode
  /// behavior belongs to the later protection phase; the field must simply
  /// survive editing (schema default false for new alarms).
  bool strictMode = false;

  /// The picked wall-clock time as a [TimeOfDay].
  TimeOfDay get time => TimeOfDay(hour: hour, minute: minute);

  /// Stores a picked [TimeOfDay] back into hour/minute.
  set time(TimeOfDay value) {
    hour = value.hour;
    minute = value.minute;
  }

  /// Whether the custom-sound option is active.
  bool get isCustomSound => soundType == kCustomSoundType;

  /// Switches between default and custom sound, clearing the URI when
  /// returning to default so stale URIs are never stored.
  void setCustomSound(bool custom) {
    soundType = custom ? kCustomSoundType : kDefaultSoundType;
    if (!custom) {
      soundUri = '';
    }
  }

  /// Structural validation key, or null when the draft can be saved.
  ///
  /// Only form-structure problems are reported here (see file docs).
  /// Returns an [AppStrings] message key, not display text.
  String? validationMessageKey() {
    if (repeatType == RepeatType.custom && repeatDays.isEmpty) {
      return 'msgValidationDays';
    }
    return null;
  }

  /// Converts to an insert companion. `nextTriggerAt` is intentionally
  /// absent: the coordinator computes and persists it when scheduling.
  AlarmsCompanion toCompanion() {
    final String trimmedLabel = label.trim();
    final String trimmedUri = soundUri.trim();
    return AlarmsCompanion.insert(
      hour: hour,
      minute: minute,
      label: Value(trimmedLabel.isEmpty ? null : trimmedLabel),
      enabled: Value(enabled),
      repeatType: Value(repeatType.dbValue),
      repeatDays:
          Value(repeatType == RepeatType.custom ? repeatDays.mask : null),
      onceDate: Value(repeatType == RepeatType.once ? onceDate : null),
      soundUri: Value(trimmedUri.isEmpty ? null : trimmedUri),
      soundType: Value(
        trimmedUri.isEmpty ? kDefaultSoundType : soundType,
      ),
      volume: Value(volume),
      fadeInEnabled: Value(fadeInEnabled),
      vibrationEnabled: Value(vibrationEnabled),
      snoozeEnabled: Value(snoozeEnabled),
      snoozeMinutes: Value(snoozeMinutes),
      snoozeMaxCount: Value(snoozeMaxCount),
      strictMode: Value(strictMode),
    );
  }

  /// Applies the draft onto [original], preserving identity (`id`),
  /// the stored schedule (`nextTriggerAt`, recomputed by the coordinator
  /// right after the update) and `createdAt`.
  Alarm applyTo(Alarm original) {
    final String trimmedLabel = label.trim();
    final String trimmedUri = soundUri.trim();
    return original.copyWith(
      label: Value(trimmedLabel.isEmpty ? null : trimmedLabel),
      hour: hour,
      minute: minute,
      enabled: enabled,
      repeatType: repeatType.dbValue,
      repeatDays: Value(
        repeatType == RepeatType.custom ? repeatDays.mask : null,
      ),
      onceDate: Value(repeatType == RepeatType.once ? onceDate : null),
      soundUri: Value(trimmedUri.isEmpty ? null : trimmedUri),
      soundType: trimmedUri.isEmpty ? kDefaultSoundType : soundType,
      volume: volume,
      fadeInEnabled: fadeInEnabled,
      vibrationEnabled: vibrationEnabled,
      snoozeEnabled: snoozeEnabled,
      snoozeMinutes: snoozeMinutes,
      snoozeMaxCount: snoozeMaxCount,
      strictMode: strictMode,
      updatedAt: DateTime.now(),
    );
  }

  static DateTime _dateOnly(DateTime value) {
    return DateTime(value.year, value.month, value.day);
  }
}
