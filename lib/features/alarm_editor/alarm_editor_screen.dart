// Create/edit alarm screen (Phase 3; stop missions added in Phase 4).
//
// Scrollable form over every Phase 3-supported database field: time,
// label, repeat (once/daily/custom via the typed `RepeatType`/`RepeatDays`
// models — the bitmask logic is never duplicated here), sound, volume,
// vibration, fade-in, snooze, and stop missions.
//
// Boundaries (deliberate):
//   - Save converts the [AlarmDraft] to a companion/row and calls the
//     controller; the screen never schedules and never touches native
//     APIs. It shows a read-only next-ring preview computed by the
//     draft through the shared `NextOccurrenceCalculator` (the same
//     source the coordinator schedules from); previewing computes, it
//     never schedules.
//   - Snooze fields are configuration + persistence only; snooze
//     execution belongs to the later Snooze phase (caption says so).
//   - Fade-in and custom-sound values are stored config; the current
//     native service still plays the default ringtone (captions say so).
//   - `strictMode` is preserved without a control; the mission section
//     edits in-memory drafts and saves them together with the alarm
//     (pre-validated before the alarm row is written, so an invalid
//     mission list never leaves a half-written alarm behind).

import 'package:alarmx/core/alarms/alarm_controller.dart';
import 'package:alarmx/core/database/database.dart';
import 'package:alarmx/core/alarms/strict_policy.dart';
import 'package:alarmx/core/l10n/app_strings.dart';
import 'package:alarmx/core/repositories/app_settings_repository.dart';
import 'package:alarmx/core/security/pin_service.dart';
import 'package:alarmx/core/models/models.dart';
import 'package:alarmx/features/alarm_editor/alarm_draft.dart';
import 'package:alarmx/features/alarm_editor/editor_card.dart';
import 'package:alarmx/features/alarm_editor/mission_section.dart';
import 'package:alarmx/features/alarm_editor/time_wheel_picker.dart';
import 'package:alarmx/features/home/alarm_formatters.dart';
import 'package:alarmx/features/missions/mission_config.dart';
import 'package:alarmx/features/missions/mission_service.dart';
import 'package:alarmx/features/security/pin_prompt.dart';
import 'package:flutter/material.dart';

/// Create (no [alarmId]) or edit form; see the file docs.
class AlarmEditorScreen extends StatefulWidget {
  const AlarmEditorScreen.create({
    super.key,
    required this.controller,
    required this.missions,
    required this.pinService,
    required this.settings,
  }) : alarmId = null;

  const AlarmEditorScreen.edit({
    super.key,
    required this.controller,
    required this.missions,
    required this.pinService,
    required this.settings,
    required int this.alarmId,
  });

  final AlarmController controller;

  /// Validated mission-list operations for the missions section.
  final MissionService missions;

  /// PIN protection for strict changes and the mission lock.
  final PinService pinService;

  /// Settings source for the Strict default (create mode).
  final AppSettingsRepository settings;

  /// Null for create, the stored id for edit.
  final int? alarmId;

  @override
  State<AlarmEditorScreen> createState() => _AlarmEditorScreenState();
}

class _AlarmEditorScreenState extends State<AlarmEditorScreen> {
  Future<Alarm?>? _loadFuture;

  @override
  void initState() {
    super.initState();
    final int? id = widget.alarmId;
    if (id != null) {
      _loadFuture = widget.controller.getAlarmById(id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppStrings strings = AppStrings.of(context);
    final int? id = widget.alarmId;
    if (id == null) {
      return _EditorScaffold(
        title: strings.createAlarmTitle,
        child: _EditorForm(
          controller: widget.controller,
          missions: widget.missions,
          pinService: widget.pinService,
          settings: widget.settings,
          existing: null,
        ),
      );
    }
    return FutureBuilder<Alarm?>(
      future: _loadFuture,
      builder: (BuildContext context, AsyncSnapshot<Alarm?> snapshot) {
        // NOTE: a completed load of a missing alarm yields data == null,
        // so the waiting state must key off connectionState, not hasData.
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _EditorScaffold(
            title: strings.editAlarmTitle,
            child: const Center(child: CircularProgressIndicator()),
          );
        }
        final Alarm? alarm = snapshot.data;
        if (snapshot.hasError || alarm == null) {
          return _EditorScaffold(
            title: strings.editAlarmTitle,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  snapshot.hasError
                      ? strings.msgLoadFailed
                      : strings.msgAlarmMissing,
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          );
        }
        return _EditorScaffold(
          title: strings.editAlarmTitle,
          child: _EditorForm(
            key: ValueKey<int>(alarm.id),
            controller: widget.controller,
            missions: widget.missions,
            pinService: widget.pinService,
            settings: widget.settings,
            existing: alarm,
          ),
        );
      },
    );
  }
}

/// Scaffold frame shared by create/edit/loading/error states.
class _EditorScaffold extends StatelessWidget {
  const _EditorScaffold({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: child,
    );
  }
}

/// The form itself. Pops with the [AlarmUiResult] when the row was
/// persisted (Home shows the message); stays open with a SnackBar when
/// validation or persistence failed so the user can fix and retry.
class _EditorForm extends StatefulWidget {
  const _EditorForm({
    super.key,
    required this.controller,
    required this.missions,
    required this.pinService,
    required this.settings,
    required this.existing,
  });

  final AlarmController controller;
  final MissionService missions;
  final PinService pinService;
  final AppSettingsRepository settings;
  final Alarm? existing;

  @override
  State<_EditorForm> createState() => _EditorFormState();
}

class _EditorFormState extends State<_EditorForm> {
  late final AlarmDraft _draft = widget.existing == null
      ? AlarmDraft()
      : AlarmDraft.fromAlarm(widget.existing!);
  late final TextEditingController _labelController =
      TextEditingController(text: _draft.label);
  late final TextEditingController _soundUriController =
      TextEditingController(text: _draft.soundUri);
  bool _saving = false;

  /// Mission drafts edited by the section; empty in create mode, loaded
  /// from storage in edit mode (see [_loadMissions]).
  List<MissionDraft> _missionDrafts = <MissionDraft>[];
  bool _missionsLoading = false;
  bool _missionsLoadFailed = false;
  bool _missionsDroppedInvalid = false;
  Future<void>? _missionsLoad;

  /// Effective PIN protection (flag on, parseable hash stored).
  bool _pinEnabled = false;

  /// Whether the PIN mission lock was unlocked this editor session.
  bool _missionsUnlocked = false;
  Future<void>? _protectionLoad;

  @override
  void initState() {
    super.initState();
    final Alarm? existing = widget.existing;
    if (existing != null) {
      _missionsLoading = true;
      _missionsLoad = _loadMissions(existing.id);
    }
    _protectionLoad = _loadProtection();
  }

  /// Loads PIN protection plus (create mode) the Strict default. Never
  /// throws: a settings read failure degrades to "unprotected" so the
  /// editor never bricks on a storage fault (the failure itself is a
  /// local read error, not an attack signal the UI can act on).
  Future<void> _loadProtection() async {
    final bool pinOn;
    final bool strictDefault;
    try {
      pinOn = await widget.pinService.isPinEnabled();
      strictDefault =
          (await widget.settings.getSettings()).strictModeDefault;
    } catch (_) {
      return;
    }
    if (!mounted) {
      return;
    }
    setState(() {
      _pinEnabled = pinOn;
      if (widget.existing == null) {
        _draft.strictMode = strictDefault;
      }
    });
  }

  /// PIN-unlocks the mission section for this editor session.
  Future<void> _unlockMissions() async {
    final AppStrings strings = AppStrings.of(context);
    final String? pin = await showPinPrompt(
      context,
      title: strings.missionUnlock,
    );
    if (pin == null || !mounted) {
      return;
    }
    bool ok = false;
    try {
      ok = await widget.pinService.verifyPin(pin);
    } catch (_) {}
    if (!mounted) {
      return;
    }
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(strings.msgPinIncorrect)),
      );
      return;
    }
    setState(() {
      _missionsUnlocked = true;
    });
  }

  /// Loads stored missions into drafts. Unexecutable rows (malformed or
  /// invalid configs) are dropped with a visible warning; `none` rows are
  /// inert and skipped silently. Never throws: failures set
  /// [_missionsLoadFailed] so saving stays blocked until a retry succeeds.
  Future<void> _loadMissions(int alarmId) async {
    try {
      final AlarmMissions loaded =
          await widget.missions.getMissionsForAlarm(alarmId);
      if (!mounted) {
        return;
      }
      setState(() {
        _missionDrafts = <MissionDraft>[
          for (final MissionEntry entry in loaded.entries)
            MissionDraft(
              id: entry.id,
              type: entry.type,
              config: entry.config,
              required: entry.required,
            ),
        ];
        _missionsDroppedInvalid = loaded.invalidCount > 0;
        _missionsLoading = false;
      });
    } catch (e) {
      debugPrint('AlarmEditorScreen: mission load failed: $e');
      if (!mounted) {
        return;
      }
      setState(() {
        _missionsLoading = false;
        _missionsLoadFailed = true;
      });
    }
  }

  void _retryMissionsLoad() {
    final Alarm? existing = widget.existing;
    if (existing == null) {
      return;
    }
    setState(() {
      _missionsLoading = true;
      _missionsLoadFailed = false;
    });
    _missionsLoad = _loadMissions(existing.id);
  }

  @override
  void dispose() {
    _labelController.dispose();
    _soundUriController.dispose();
    super.dispose();
  }

  Future<void> _pickTime() async {
    final TimeOfDay? picked = await showTimeWheelPicker(
      context: context,
      initialTime: _draft.time,
      remainingText: _remainingPreview,
    );
    if (picked != null && mounted) {
      setState(() {
        _draft.time = picked;
      });
    }
  }

  /// Read-only "time remaining" preview for a candidate [time].
  ///
  /// Shown under the time button (live draft) and at the bottom of the
  /// wheel dialog (candidate wheel position). Pure delegation to
  /// [AlarmDraft.nextOccurrence] + [formatRemainingDuration].
  String _remainingPreview(TimeOfDay time) {
    final AppStrings strings = AppStrings.of(context);
    final DateTime now = DateTime.now();
    final DateTime? target = _draft.nextOccurrence(now: now, atTime: time);
    if (target == null) {
      return strings.editorRemainingNone;
    }
    final Duration diff = target.difference(now);
    if (diff.inMinutes < 1) {
      return strings.editorRemainingSoon;
    }
    return formatRemainingDuration(
      diff,
      Localizations.localeOf(context).languageCode,
    );
  }

  Future<void> _pickDate() async {
    final DateTime now = DateTime.now();
    final DateTime firstDate = DateTime(2020);
    final DateTime lastDate = DateTime(now.year + 5, now.month, now.day);
    DateTime initialDate = _draft.onceDate;
    if (initialDate.isBefore(firstDate)) {
      initialDate = firstDate;
    } else if (initialDate.isAfter(lastDate)) {
      initialDate = lastDate;
    }
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: lastDate,
    );
    if (picked != null && mounted) {
      setState(() {
        _draft.onceDate = DateTime(picked.year, picked.month, picked.day);
      });
    }
  }

  Future<void> _save() async {
    final AppStrings strings = AppStrings.of(context);
    final Future<void>? pendingProtection = _protectionLoad;
    if (pendingProtection != null) {
      await pendingProtection;
    }
    if (!mounted) {
      return;
    }
    final String? invalidKey = _draft.validationMessageKey();
    if (invalidKey != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(strings.text(invalidKey))),
      );
      return;
    }
    // Strict-removal gates (Phase 5): the ring-proximity blackout first
    // (no PIN prompt when the answer is already no), then PIN
    // authentication when a PIN is enabled. Either failure keeps the
    // editor open with the reason shown.
    final bool wasStrict = widget.existing?.strictMode ?? false;
    if (wasStrict && !_draft.strictMode) {
      if (!StrictModePolicy.canDisableStrict(
        wasStrict: true,
        nextTriggerAt: widget.existing?.nextTriggerAt,
        now: DateTime.now(),
      )) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(strings.msgStrictBlackout)),
        );
        return;
      }
      if (_pinEnabled) {
        final String? pin = await showPinPrompt(
          context,
          title: strings.pinUnlockTitle,
        );
        if (!mounted || pin == null) {
          return;
        }
        bool ok = false;
        try {
          ok = await widget.pinService.verifyPin(pin);
        } catch (_) {}
        if (!mounted) {
          return;
        }
        if (!ok) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(strings.msgPinIncorrect)),
          );
          return;
        }
      }
    }
    setState(() {
      _saving = true;
    });
    try {
      final Future<void>? pendingMissions = _missionsLoad;
      if (pendingMissions != null) {
        await pendingMissions;
      }
      if (!mounted) {
        return;
      }
      if (_missionsLoadFailed) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(strings.msgMissionsLoadFailed)),
        );
        return;
      }
      // Pre-validate before writing anything: an invalid mission list must
      // never leave a half-written alarm behind.
      final List<String> missionErrors =
          MissionService.validateDrafts(_missionDrafts);
      if (missionErrors.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(strings.text(missionErrors.first))),
        );
        return;
      }
      final Alarm? existing = widget.existing;
      if (existing != null && !_draft.enabled) {
        _maybeReEnable(existing);
      }
      final AlarmUiResult result = existing == null
          ? await widget.controller.createAlarm(_draft.toCompanion())
          : await widget.controller.updateAlarm(_draft.applyTo(existing));
      if (!mounted) {
        return;
      }
      if (result.persisted) {
        final int? alarmId = result.alarmId ?? existing?.id;
        if (alarmId == null) {
          // The alarm row exists but its id is unknown; staying open so
          // the missions are never silently dropped.
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(strings.msgMissionSaveFailed)),
          );
          return;
        }
        try {
          await widget.missions
              .saveMissionsForAlarm(alarmId, _missionDrafts);
        } on MissionValidationException catch (validation) {
          // Defensive: drafts were pre-validated above, so this only
          // fires if drafts change mid-save (single-threaded: never).
          if (!mounted) {
            return;
          }
          final List<String> keys = validation.messageKeys;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                strings.text(
                  keys.isEmpty ? 'msgMissionInvalid' : keys.first,
                ),
              ),
            ),
          );
          return;
        } catch (e) {
          debugPrint('AlarmEditorScreen: mission save failed: $e');
          if (!mounted) {
            return;
          }
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(strings.msgMissionSaveFailed)),
          );
          return;
        }
        if (!mounted) {
          return;
        }
        Navigator.of(context).pop(result);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(strings.text(result.messageKey))),
        );
      }
    } catch (e) {
      // Defensive: the controller never throws, so this means a local
      // conversion bug. Stay open and report instead of crashing.
      debugPrint('AlarmEditorScreen: save failed unexpectedly: $e');
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.existing == null
                ? strings.msgCreateFailed
                : strings.msgUpdateFailed,
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  /// Auto re-enables a disabled alarm being edited when its time was
  /// moved to a valid future occurrence: setting the time is an
  /// explicit "wake me" gesture, so the alarm should ring. Label-only
  /// (or any other non-time) edits never flip the switch.
  void _maybeReEnable(Alarm existing) {
    final bool timeChanged = _draft.hour != existing.hour ||
        _draft.minute != existing.minute ||
        (_draft.repeatType == RepeatType.once &&
            !_isSameDay(_draft.onceDate, existing.onceDate));
    if (timeChanged && _draft.nextOccurrence() != null) {
      _draft.enabled = true;
    }
  }

  static bool _isSameDay(DateTime a, DateTime? b) {
    return b != null &&
        a.year == b.year &&
        a.month == b.month &&
        a.day == b.day;
  }

  @override
  Widget build(BuildContext context) {
    final AppStrings strings = AppStrings.of(context);
    return Column(
      children: <Widget>[
        Expanded(
          child: ListView(
            padding: const EdgeInsetsDirectional.only(
              start: 16,
              end: 16,
              top: 12,
              bottom: 12,
            ),
            children: <Widget>[
              TextField(
                key: const Key('editor_label_field'),
                controller: _labelController,
                decoration: InputDecoration(
                  labelText: strings.labelLabel,
                  hintText: strings.labelHint,
                  prefixIcon: const Icon(Icons.label_outline),
                  filled: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                textInputAction: TextInputAction.done,
                maxLength: 120,
                onChanged: (String value) {
                  _draft.label = value;
                },
              ),
              const SizedBox(height: 12),
              _EnabledCard(
                enabled: _draft.enabled,
                onChanged: (bool value) {
                  setState(() {
                    _draft.enabled = value;
                  });
                },
              ),
              const SizedBox(height: 12),
              _TimeCard(
                onPickTime: _pickTime,
                draft: _draft,
                remainingPreview: _remainingPreview(_draft.time),
              ),
              const SizedBox(height: 12),
              _RepeatCard(
                draft: _draft,
                onChanged: () => setState(() {}),
                onPickDate: _pickDate,
              ),
              const SizedBox(height: 12),
              _SoundCard(
                draft: _draft,
                soundUriController: _soundUriController,
                onChanged: () => setState(() {}),
              ),
              const SizedBox(height: 12),
              _TogglesCard(
                draft: _draft,
                onChanged: () => setState(() {}),
              ),
              const SizedBox(height: 12),
              _SnoozeCard(
                draft: _draft,
                onChanged: () => setState(() {}),
              ),
              const SizedBox(height: 12),
              _StrictCard(
                draft: _draft,
                onChanged: () => setState(() {}),
              ),
              const SizedBox(height: 12),
              MissionSectionCard(
                drafts: _missionDrafts,
                isLoading: _missionsLoading,
                loadFailed: _missionsLoadFailed,
                droppedInvalid: _missionsDroppedInvalid,
                onChanged: () => setState(() {}),
                onRetryLoad: _retryMissionsLoad,
                locked: _pinEnabled &&
                    _draft.strictMode &&
                    !_missionsUnlocked,
                onUnlock: _unlockMissions,
              ),
            ],
          ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsetsDirectional.only(
              start: 16,
              end: 16,
              bottom: 16,
            ),
            child: SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton(
                key: const Key('editor_save_button'),
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(strings.save),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Enabled-state switch (text state, never color-only).
class _EnabledCard extends StatelessWidget {
  const _EnabledCard({required this.enabled, required this.onChanged});

  final bool enabled;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final AppStrings strings = AppStrings.of(context);
    return EditorCard(
      child: SwitchListTile(
        secondary: Icon(enabled ? Icons.alarm_on : Icons.alarm_off),
        title: Text(enabled ? strings.onLabel : strings.offLabel),
        value: enabled,
        onChanged: onChanged,
      ),
    );
  }
}

/// Time picker row.
class _TimeCard extends StatelessWidget {
  const _TimeCard({
    required this.draft,
    required this.onPickTime,
    required this.remainingPreview,
  });

  final AlarmDraft draft;
  final VoidCallback onPickTime;

  /// Precomputed "time remaining" line for the live draft.
  final String remainingPreview;

  @override
  Widget build(BuildContext context) {
    final AppStrings strings = AppStrings.of(context);
    final ThemeData theme = Theme.of(context);
    return EditorCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              children: <Widget>[
                const EditorHeaderIcon(Icons.schedule),
                const SizedBox(width: 12),
                Text(
                  strings.timeLabel,
                  style: theme.textTheme.titleMedium,
                ),
                const Spacer(),
                FilledButton.tonal(
                  key: const Key('editor_time_button'),
                  onPressed: onPickTime,
                  child: Text(
                    draft.time.format(context),
                    style: theme.textTheme.headlineSmall,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              key: const Key('editor_remaining'),
              children: <Widget>[
                Icon(
                  Icons.timelapse,
                  size: 18,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${strings.editorRemaining}: $remainingPreview',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Repeat selector: once (with date) / daily / custom (with weekday chips).
class _RepeatCard extends StatelessWidget {
  const _RepeatCard({
    required this.draft,
    required this.onChanged,
    required this.onPickDate,
  });

  final AlarmDraft draft;
  final VoidCallback onChanged;
  final VoidCallback onPickDate;

  @override
  Widget build(BuildContext context) {
    final AppStrings strings = AppStrings.of(context);
    return EditorCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            _SectionHeader(strings.repeatLabel, icon: Icons.repeat),
            const SizedBox(height: 12),
            SegmentedButton<RepeatType>(
              segments: <ButtonSegment<RepeatType>>[
                ButtonSegment<RepeatType>(
                  value: RepeatType.once,
                  label: Text(strings.repeatOnce),
                ),
                ButtonSegment<RepeatType>(
                  value: RepeatType.daily,
                  label: Text(strings.repeatDaily),
                ),
                ButtonSegment<RepeatType>(
                  value: RepeatType.custom,
                  label: Text(strings.repeatCustom),
                ),
              ],
              selected: <RepeatType>{draft.repeatType},
              onSelectionChanged: (Set<RepeatType> selected) {
                draft.repeatType = selected.first;
                onChanged();
              },
            ),
            if (draft.repeatType == RepeatType.once) ...<Widget>[
              const SizedBox(height: 12),
              Row(
                children: <Widget>[
                  const Icon(Icons.calendar_month),
                  const SizedBox(width: 12),
                  Text(
                    strings.dateLabel,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const Spacer(),
                  FilledButton.tonal(
                    key: const Key('editor_date_button'),
                    onPressed: onPickDate,
                    child: Text(
                      MaterialLocalizations.of(context)
                          .formatMediumDate(draft.onceDate),
                    ),
                  ),
                ],
              ),
            ],
            if (draft.repeatType == RepeatType.custom) ...<Widget>[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: <Widget>[
                  for (final Weekday day in Weekday.values)
                    FilterChip(
                      label: Text(weekdayName(strings, day)),
                      selected: draft.repeatDays.has(day),
                      onSelected: (_) {
                        draft.repeatDays = draft.repeatDays.toggle(day);
                        onChanged();
                      },
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Sound type + optional URI + volume.
class _SoundCard extends StatelessWidget {
  const _SoundCard({
    required this.draft,
    required this.soundUriController,
    required this.onChanged,
  });

  final AlarmDraft draft;
  final TextEditingController soundUriController;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final AppStrings strings = AppStrings.of(context);
    final ThemeData theme = Theme.of(context);
    return EditorCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            _SectionHeader(strings.soundLabel, icon: Icons.music_note),
            const SizedBox(height: 12),
            SegmentedButton<bool>(
              segments: <ButtonSegment<bool>>[
                ButtonSegment<bool>(
                  value: false,
                  label: Text(strings.soundDefault),
                ),
                ButtonSegment<bool>(
                  value: true,
                  label: Text(strings.soundCustom),
                ),
              ],
              selected: <bool>{draft.isCustomSound},
              onSelectionChanged: (Set<bool> selected) {
                draft.setCustomSound(selected.first);
                if (!draft.isCustomSound) {
                  soundUriController.text = '';
                }
                onChanged();
              },
            ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('editor_sound_uri_field'),
              controller: soundUriController,
              enabled: draft.isCustomSound,
              decoration: InputDecoration(
                labelText: strings.soundUriLabel,
                hintText: strings.soundUriHint,
                border: const OutlineInputBorder(),
              ),
              textInputAction: TextInputAction.done,
              onChanged: (String value) {
                draft.soundUri = value;
              },
            ),
            const SizedBox(height: 12),
            Row(
              children: <Widget>[
                const Icon(Icons.volume_up),
                Expanded(
                  child: Slider(
                    value: draft.volume.toDouble(),
                    min: 0,
                    max: 100,
                    divisions: 20,
                    label: '${draft.volume}',
                    onChanged: (double value) {
                      draft.volume = value.round();
                      onChanged();
                    },
                  ),
                ),
                SizedBox(
                  width: 56,
                  child: Text(
                    '${strings.volumeLabel} ${draft.volume}',
                    style: theme.textTheme.bodySmall,
                    textAlign: TextAlign.end,
                  ),
                ),
              ],
            ),
            Text(
              strings.soundFutureCaption,
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

/// Vibration + fade-in switches.
class _TogglesCard extends StatelessWidget {
  const _TogglesCard({required this.draft, required this.onChanged});

  final AlarmDraft draft;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final AppStrings strings = AppStrings.of(context);
    return EditorCard(
      child: Column(
        children: <Widget>[
          SwitchListTile(
            secondary: const Icon(Icons.vibration),
            title: Text(strings.vibrationLabel),
            value: draft.vibrationEnabled,
            onChanged: (bool value) {
              draft.vibrationEnabled = value;
              onChanged();
            },
          ),
          const Divider(height: 1, indent: 16, endIndent: 16),
          SwitchListTile(
            secondary: const Icon(Icons.trending_up),
            title: Text(strings.fadeInLabel),
            subtitle: Text(strings.fadeInCaption),
            value: draft.fadeInEnabled,
            onChanged: (bool value) {
              draft.fadeInEnabled = value;
              onChanged();
            },
          ),
        ],
      ),
    );
  }
}

/// Strict Mode toggle (Phase 5).
///
/// Flipping the switch only edits the draft; turning Strict off a
/// stored strict alarm is gated at save time (ring-proximity blackout,
/// then the PIN when enabled). The caption states the honest boundary:
/// Strict gates dismissal inside the app, never the system.
class _StrictCard extends StatelessWidget {
  const _StrictCard({required this.draft, required this.onChanged});

  final AlarmDraft draft;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final AppStrings strings = AppStrings.of(context);
    return EditorCard(
      child: SwitchListTile(
        key: const Key('editor_strict_switch'),
        title: Text(strings.strictModeLabel),
        subtitle: Text(strings.strictModeCaption),
        value: draft.strictMode,
        onChanged: (bool value) {
          draft.strictMode = value;
          onChanged();
        },
      ),
    );
  }
}

/// Snooze configuration (stored only; no execution in this phase).
class _SnoozeCard extends StatelessWidget {
  const _SnoozeCard({required this.draft, required this.onChanged});

  final AlarmDraft draft;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final AppStrings strings = AppStrings.of(context);
    final ThemeData theme = Theme.of(context);
    final List<int> minuteOptions = <int>{
      ...kSnoozeMinuteOptions,
      draft.snoozeMinutes,
    }.toList()
      ..sort();
    final List<int> countOptions = <int>{
      ...kSnoozeMaxCountOptions,
      draft.snoozeMaxCount,
    }.toList()
      ..sort();
    return EditorCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              children: <Widget>[
                const EditorHeaderIcon(Icons.snooze),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    strings.snoozeLabel,
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                Switch(
                  key: const Key('editor_snooze_switch'),
                  value: draft.snoozeEnabled,
                  onChanged: (bool value) {
                    draft.snoozeEnabled = value;
                    onChanged();
                  },
                ),
              ],
            ),
            if (draft.snoozeEnabled) ...<Widget>[
              const SizedBox(height: 12),
              Text(strings.snoozeDuration, style: theme.textTheme.bodyLarge),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: <Widget>[
                  for (final int minutes in minuteOptions)
                    ChoiceChip(
                      label: Text('$minutes'),
                      selected: draft.snoozeMinutes == minutes,
                      onSelected: (_) {
                        draft.snoozeMinutes = minutes;
                        onChanged();
                      },
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      strings.snoozeMaxCount,
                      style: theme.textTheme.bodyLarge,
                    ),
                  ),
                  DropdownButton<int>(
                    value: draft.snoozeMaxCount,
                    items: <DropdownMenuItem<int>>[
                      for (final int count in countOptions)
                        DropdownMenuItem<int>(
                          value: count,
                          child: Text('$count'),
                        ),
                    ],
                    onChanged: (int? value) {
                      if (value != null) {
                        draft.snoozeMaxCount = value;
                        onChanged();
                      }
                    },
                  ),
                ],
              ),
            ],
            const SizedBox(height: 8),
            Text(
              strings.snoozeCaption,
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

/// Section header with heading semantics for screen readers.
class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.label, {this.icon});

  final String label;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final IconData? chip = icon;
    return Row(
      children: <Widget>[
        if (chip != null) ...<Widget>[
          EditorHeaderIcon(chip),
          const SizedBox(width: 12),
        ],
        Expanded(
          child: Semantics(
            header: true,
            child: Text(
              label,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
        ),
      ],
    );
  }
}
