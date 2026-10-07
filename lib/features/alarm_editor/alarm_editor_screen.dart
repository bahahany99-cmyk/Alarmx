// Create/edit alarm screen (Phase 3).
//
// Scrollable form over every Phase 3-supported database field: time,
// label, repeat (once/daily/custom via the typed `RepeatType`/`RepeatDays`
// models — the bitmask logic is never duplicated here), sound, volume,
// vibration, fade-in, snooze, and a stop-mission placeholder.
//
// Boundaries (deliberate):
//   - Save converts the [AlarmDraft] to a companion/row and calls the
//     controller; the screen never schedules, never computes trigger
//     times, and never touches native APIs.
//   - Snooze fields are configuration + persistence only; snooze
//     execution belongs to the later Snooze phase (caption says so).
//   - Fade-in and custom-sound values are stored config; the current
//     native service still plays the default ringtone (captions say so).
//   - `strictMode` is preserved without a control; the mission section is
//     a static placeholder (no mission rows are read or written).

import 'package:alarmx/core/alarms/alarm_controller.dart';
import 'package:alarmx/core/database/database.dart';
import 'package:alarmx/core/l10n/app_strings.dart';
import 'package:alarmx/core/models/models.dart';
import 'package:alarmx/features/alarm_editor/alarm_draft.dart';
import 'package:alarmx/features/home/alarm_formatters.dart';
import 'package:flutter/material.dart';

/// Create (no [alarmId]) or edit form; see the file docs.
class AlarmEditorScreen extends StatefulWidget {
  const AlarmEditorScreen.create({
    super.key,
    required this.controller,
  }) : alarmId = null;

  const AlarmEditorScreen.edit({
    super.key,
    required this.controller,
    required int this.alarmId,
  });

  final AlarmController controller;

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
    required this.existing,
  });

  final AlarmController controller;
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

  @override
  void dispose() {
    _labelController.dispose();
    _soundUriController.dispose();
    super.dispose();
  }

  Future<void> _pickTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _draft.time,
    );
    if (picked != null && mounted) {
      setState(() {
        _draft.time = picked;
      });
    }
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
    final String? invalidKey = _draft.validationMessageKey();
    if (invalidKey != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(strings.text(invalidKey))),
      );
      return;
    }
    setState(() {
      _saving = true;
    });
    try {
      final Alarm? existing = widget.existing;
      final AlarmUiResult result = existing == null
          ? await widget.controller.createAlarm(_draft.toCompanion())
          : await widget.controller.updateAlarm(_draft.applyTo(existing));
      if (!mounted) {
        return;
      }
      if (result.persisted) {
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
              _EnabledCard(
                enabled: _draft.enabled,
                onChanged: (bool value) {
                  setState(() {
                    _draft.enabled = value;
                  });
                },
              ),
              const SizedBox(height: 12),
              _TimeCard(onPickTime: _pickTime, draft: _draft),
              const SizedBox(height: 12),
              TextField(
                key: const Key('editor_label_field'),
                controller: _labelController,
                decoration: InputDecoration(
                  labelText: strings.labelLabel,
                  hintText: strings.labelHint,
                  border: const OutlineInputBorder(),
                ),
                textInputAction: TextInputAction.done,
                maxLength: 120,
                onChanged: (String value) {
                  _draft.label = value;
                },
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
              const _MissionPlaceholder(),
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
    return Card(
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
  const _TimeCard({required this.draft, required this.onPickTime});

  final AlarmDraft draft;
  final VoidCallback onPickTime;

  @override
  Widget build(BuildContext context) {
    final AppStrings strings = AppStrings.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: <Widget>[
            const Icon(Icons.schedule),
            const SizedBox(width: 12),
            Text(
              strings.timeLabel,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const Spacer(),
            FilledButton.tonal(
              key: const Key('editor_time_button'),
              onPressed: onPickTime,
              child: Text(
                draft.time.format(context),
                style: Theme.of(context).textTheme.headlineSmall,
              ),
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
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            _SectionHeader(strings.repeatLabel),
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
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            _SectionHeader(strings.soundLabel),
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
    return Card(
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
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              children: <Widget>[
                const Icon(Icons.snooze),
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

/// Static stop-mission placeholder: no mission rows are read or written in
/// this phase, and no mission engines exist yet. The section reserves the
/// editor slot the future mission selector will plug into.
class _MissionPlaceholder extends StatelessWidget {
  const _MissionPlaceholder();

  @override
  Widget build(BuildContext context) {
    final AppStrings strings = AppStrings.of(context);
    return Card(
      child: ListTile(
        enabled: false,
        leading: const Icon(Icons.emoji_events_outlined),
        title: Text(strings.missionTitle),
        subtitle: Text(
          '${strings.missionNone} — ${strings.missionCaption}',
        ),
      ),
    );
  }
}

/// Section header with heading semantics for screen readers.
class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      header: true,
      child: Text(
        label,
        style: Theme.of(context).textTheme.titleMedium,
      ),
    );
  }
}
