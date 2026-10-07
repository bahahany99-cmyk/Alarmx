// Mission editor section (Phase 4).
//
// The stop-mission list inside the create/edit alarm form: list, add,
// type, configure, required, reorder, edit, delete. [MissionSectionCard]
// owns the in-memory drafts (mutated in place, changes reported through
// [onChanged]); persistence belongs to the surrounding form, which saves
// drafts together with the alarm.
//
// Boundaries (deliberate):
//   - Configuration is text and fixed choices only: expected typing text,
//     photo label hint, expected QR/barcode value, shake count, math
//     difficulty + count. No camera, no sensors, no permissions anywhere
//     in this section — those are requested just-in-time while a mission
//     executes, never while configuring.
//   - Rows show friendly names and one-line summaries, never raw JSON.
//   - Dialog edits work on a copy: cancelling leaves the draft
//     untouched; saving validates and reports inline.
//   - The card never reads or writes the database; loading, saving, and
//     load retries are the form's job.

import 'package:alarmx/core/l10n/app_strings.dart';
import 'package:alarmx/core/models/models.dart';
import 'package:alarmx/features/missions/mission_config.dart';
import 'package:flutter/material.dart';

/// Mission types the editor can add, in roadmap order (typing, photo,
/// QR, barcode, shake, math). `MissionType.none` is not offered: "no
/// missions" is expressed by an empty list.
const List<MissionType> kMissionTypeOptions = <MissionType>[
  MissionType.typing,
  MissionType.photo,
  MissionType.qr,
  MissionType.barcode,
  MissionType.shake,
  MissionType.math,
];

/// Friendly display name for [type].
String missionTypeName(AppStrings strings, MissionType type) {
  switch (type) {
    case MissionType.typing:
      return strings.missionTyping;
    case MissionType.photo:
      return strings.missionPhoto;
    case MissionType.qr:
      return strings.missionQr;
    case MissionType.barcode:
      return strings.missionBarcode;
    case MissionType.shake:
      return strings.missionShake;
    case MissionType.math:
      return strings.missionMath;
    case MissionType.none:
      return strings.missionNone;
  }
}

/// Friendly name for a math [difficulty].
String mathDifficultyName(AppStrings strings, MathDifficulty difficulty) {
  switch (difficulty) {
    case MathDifficulty.easy:
      return strings.mathEasy;
    case MathDifficulty.medium:
      return strings.mathMedium;
    case MathDifficulty.hard:
      return strings.mathHard;
  }
}

/// One-line friendly summary of the draft's config (never raw JSON).
String missionDraftSummary(AppStrings strings, MissionDraft draft) {
  final MissionConfig config = draft.config;
  if (config is TypingMissionConfig) {
    return '\u201c${_truncate(config.expectedText.trim(), 40)}\u201d';
  }
  if (config is PhotoMissionConfig) {
    final String label = config.label.trim();
    return label.isEmpty ? '\u2014' : _truncate(label, 40);
  }
  if (config is QrMissionConfig) {
    return _truncate(config.expectedValue.trim(), 40);
  }
  if (config is BarcodeMissionConfig) {
    return _truncate(config.expectedValue.trim(), 40);
  }
  if (config is ShakeMissionConfig) {
    return '\u00d7${config.requiredCount}';
  }
  if (config is MathMissionConfig) {
    return '${mathDifficultyName(strings, config.difficulty)} \u00b7 '
        '${config.questionCount}';
  }
  return '\u2014';
}

String _truncate(String value, int maxLength) {
  if (value.length <= maxLength) {
    return value;
  }
  return '${value.substring(0, maxLength)}\u2026';
}

IconData _iconFor(MissionType type) {
  switch (type) {
    case MissionType.typing:
      return Icons.keyboard;
    case MissionType.photo:
      return Icons.photo_camera;
    case MissionType.qr:
      return Icons.qr_code;
    case MissionType.barcode:
      return Icons.qr_code_scanner;
    case MissionType.shake:
      return Icons.vibration;
    case MissionType.math:
      return Icons.calculate;
    case MissionType.none:
      return Icons.emoji_events_outlined;
  }
}

/// Mission list card for the alarm form; see the file docs.
class MissionSectionCard extends StatelessWidget {
  const MissionSectionCard({
    super.key,
    required this.drafts,
    required this.isLoading,
    required this.loadFailed,
    required this.droppedInvalid,
    required this.onChanged,
    required this.onRetryLoad,
    this.locked = false,
    this.onUnlock,
  });

  /// Live draft list, mutated in place (add/edit/delete/reorder/toggle).
  final List<MissionDraft> drafts;

  /// True while stored missions load (edit mode).
  final bool isLoading;

  /// True when the stored-mission load failed; shows an error + retry.
  final bool loadFailed;

  /// True when unexecutable stored rows were dropped on load.
  final bool droppedInvalid;

  /// Called after every draft mutation so the form rebuilds.
  final VoidCallback onChanged;

  /// Reloads stored missions after a load failure.
  final VoidCallback onRetryLoad;

  /// PIN lock (Phase 5): when true the list is hidden behind an unlock
  /// prompt because the alarm is strict and a PIN is enabled.
  final bool locked;

  /// PIN-unlock entry point; called by the unlock button when [locked].
  final VoidCallback? onUnlock;

  Future<void> _add(BuildContext context) async {
    final MissionType? type = await showMissionTypePicker(context);
    if (type == null || !context.mounted) {
      return;
    }
    final MissionDraft? created = await showMissionConfigDialog(
      context,
      MissionDraft.withDefaults(type),
      isNew: true,
    );
    if (created != null) {
      drafts.add(created);
      onChanged();
    }
  }

  Future<void> _edit(BuildContext context, int index) async {
    if (index < 0 || index >= drafts.length) {
      return;
    }
    final MissionDraft? edited = await showMissionConfigDialog(
      context,
      drafts[index].copy(),
      isNew: false,
    );
    if (edited != null) {
      drafts[index] = edited;
      onChanged();
    }
  }

  Future<void> _delete(BuildContext context, int index) async {
    if (index < 0 || index >= drafts.length) {
      return;
    }
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        final AppStrings dialogStrings = AppStrings.of(dialogContext);
        return AlertDialog(
          title: Text(dialogStrings.missionDeleteTitle),
          content: Text(dialogStrings.missionDeleteMessage),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(dialogStrings.cancel),
            ),
            FilledButton(
              key: const Key('mission_delete_confirm'),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(dialogStrings.delete),
            ),
          ],
        );
      },
    );
    if (confirmed == true) {
      drafts.removeAt(index);
      onChanged();
    }
  }

  void _move(int index, int delta) {
    final int other = index + delta;
    if (index < 0 ||
        index >= drafts.length ||
        other < 0 ||
        other >= drafts.length) {
      return;
    }
    final MissionDraft moved = drafts.removeAt(index);
    drafts.insert(other, moved);
    onChanged();
  }

  void _toggleRequired(int index, bool value) {
    if (index >= 0 && index < drafts.length) {
      drafts[index].required = value;
      onChanged();
    }
  }

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
            Row(
              children: <Widget>[
                const Icon(Icons.emoji_events_outlined),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    strings.missionTitle,
                    style: theme.textTheme.titleMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (isLoading)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (loadFailed)
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Text(
                    strings.msgMissionsLoadFailed,
                    style: theme.textTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton(
                    key: const Key('missions_retry_button'),
                    onPressed: onRetryLoad,
                    child: Text(strings.missionRetry),
                  ),
                ],
              )
            else if (locked)
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  const SizedBox(height: 8),
                  const Icon(Icons.lock),
                  const SizedBox(height: 8),
                  Text(
                    strings.missionLocked,
                    style: theme.textTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton(
                    key: const Key('missions_unlock_button'),
                    onPressed: onUnlock,
                    child: Text(strings.missionUnlock),
                  ),
                ],
              )
            else ...<Widget>[
              if (droppedInvalid)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    strings.msgMissionInvalid,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.error,
                    ),
                  ),
                ),
              if (drafts.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    '${strings.missionNone} \u2014 ${strings.missionCaption}',
                    style: theme.textTheme.bodyMedium,
                  ),
                )
              else
                for (int i = 0; i < drafts.length; i++)
                  _MissionRow(
                    index: i,
                    draft: drafts[i],
                    isFirst: i == 0,
                    isLast: i == drafts.length - 1,
                    onToggleRequired: (bool value) =>
                        _toggleRequired(i, value),
                    onMoveUp: () => _move(i, -1),
                    onMoveDown: () => _move(i, 1),
                    onEdit: () => _edit(context, i),
                    onDelete: () => _delete(context, i),
                  ),
              const SizedBox(height: 4),
              OutlinedButton.icon(
                key: const Key('mission_add_button'),
                onPressed: () => _add(context),
                icon: const Icon(Icons.add),
                label: Text(strings.missionAdd),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// One editable mission row: friendly name, config summary,
/// required toggle, and move/edit/delete actions.
class _MissionRow extends StatelessWidget {
  const _MissionRow({
    required this.index,
    required this.draft,
    required this.isFirst,
    required this.isLast,
    required this.onToggleRequired,
    required this.onMoveUp,
    required this.onMoveDown,
    required this.onEdit,
    required this.onDelete,
  });

  final int index;
  final MissionDraft draft;
  final bool isFirst;
  final bool isLast;
  final ValueChanged<bool> onToggleRequired;
  final VoidCallback onMoveUp;
  final VoidCallback onMoveDown;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final AppStrings strings = AppStrings.of(context);
    final ThemeData theme = Theme.of(context);
    final String requirement =
        draft.required ? strings.missionRequired : strings.missionOptional;
    return Container(
      key: Key('mission_row_$index'),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        border: Border.all(color: theme.dividerColor),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          ListTile(
            leading: Icon(_iconFor(draft.type)),
            title: Text(
              '${index + 1}. ${missionTypeName(strings, draft.type)}',
            ),
            subtitle:
                Text('${missionDraftSummary(strings, draft)} \u00b7 '
                    '$requirement'),
          ),
          Padding(
            padding: const EdgeInsetsDirectional.only(
              start: 8,
              end: 4,
              bottom: 4,
            ),
            child: Row(
              children: <Widget>[
                Switch(
                  key: Key('mission_required_$index'),
                  value: draft.required,
                  onChanged: onToggleRequired,
                ),
                const Spacer(),
                IconButton(
                  key: Key('mission_up_$index'),
                  tooltip: strings.missionMoveUp,
                  icon: const Icon(Icons.arrow_upward),
                  onPressed: isFirst ? null : onMoveUp,
                ),
                IconButton(
                  key: Key('mission_down_$index'),
                  tooltip: strings.missionMoveDown,
                  icon: const Icon(Icons.arrow_downward),
                  onPressed: isLast ? null : onMoveDown,
                ),
                IconButton(
                  key: Key('mission_edit_$index'),
                  tooltip: strings.missionEdit,
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: onEdit,
                ),
                IconButton(
                  key: Key('mission_delete_$index'),
                  tooltip: strings.delete,
                  icon: const Icon(Icons.delete_outline),
                  onPressed: onDelete,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Type picker dialog; returns the chosen type or `null` on dismiss.
Future<MissionType?> showMissionTypePicker(BuildContext context) {
  return showDialog<MissionType>(
    context: context,
    builder: (BuildContext dialogContext) {
      final AppStrings dialogStrings = AppStrings.of(dialogContext);
      return SimpleDialog(
        title: Text(dialogStrings.missionPickType),
        children: <Widget>[
          for (final MissionType type in kMissionTypeOptions)
            SimpleDialogOption(
              key: Key('mission_type_option_${type.name}'),
              onPressed: () => Navigator.of(dialogContext).pop(type),
              child: Row(
                children: <Widget>[
                  Icon(_iconFor(type)),
                  const SizedBox(width: 12),
                  Text(missionTypeName(dialogStrings, type)),
                ],
              ),
            ),
        ],
      );
    },
  );
}

/// Config dialog for [draft] (already a copy); returns the edited draft
/// or `null` when cancelled. Saving validates inline and stays open on
/// errors instead of producing an invalid draft.
Future<MissionDraft?> showMissionConfigDialog(
  BuildContext context,
  MissionDraft draft, {
  required bool isNew,
}) {
  return showDialog<MissionDraft>(
    context: context,
    builder: (_) => _MissionConfigDialog(draft: draft, isNew: isNew),
  );
}

class _MissionConfigDialog extends StatefulWidget {
  const _MissionConfigDialog({required this.draft, required this.isNew});

  final MissionDraft draft;
  final bool isNew;

  @override
  State<_MissionConfigDialog> createState() => _MissionConfigDialogState();
}

class _MissionConfigDialogState extends State<_MissionConfigDialog> {
  late final TextEditingController _textController =
      TextEditingController(text: _initialText(widget.draft.config));
  late int _count = _initialCount(widget.draft.config);
  late MathDifficulty _difficulty = _initialDifficulty(widget.draft.config);
  late bool _required = widget.draft.required;
  String? _errorKey;

  static String _initialText(MissionConfig config) {
    if (config is TypingMissionConfig) {
      return config.expectedText;
    }
    if (config is PhotoMissionConfig) {
      return config.label;
    }
    if (config is QrMissionConfig) {
      return config.expectedValue;
    }
    if (config is BarcodeMissionConfig) {
      return config.expectedValue;
    }
    return '';
  }

  static int _initialCount(MissionConfig config) {
    if (config is ShakeMissionConfig) {
      return config.requiredCount;
    }
    if (config is MathMissionConfig) {
      return config.questionCount;
    }
    return 0;
  }

  static MathDifficulty _initialDifficulty(MissionConfig config) {
    if (config is MathMissionConfig) {
      return config.difficulty;
    }
    return MathDifficulty.easy;
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  MissionConfig _buildConfig() {
    switch (widget.draft.type) {
      case MissionType.typing:
        return TypingMissionConfig(_textController.text);
      case MissionType.photo:
        return PhotoMissionConfig(_textController.text);
      case MissionType.qr:
        return QrMissionConfig(_textController.text);
      case MissionType.barcode:
        return BarcodeMissionConfig(_textController.text);
      case MissionType.shake:
        return ShakeMissionConfig(_count);
      case MissionType.math:
        return MathMissionConfig(
          questionCount: _count,
          difficulty: _difficulty,
        );
      case MissionType.none:
        // Unreachable: the picker never offers `none`, and validation
        // rejects the inert fallback before anything can be saved.
        return const PhotoMissionConfig();
    }
  }

  void _save() {
    final MissionConfig config = _buildConfig();
    final String? errorKey = config.validationMessageKey();
    if (errorKey != null || config.type != widget.draft.type) {
      setState(() {
        _errorKey = errorKey ?? 'msgMissionInvalid';
      });
      return;
    }
    Navigator.of(context).pop(
      MissionDraft(
        id: widget.draft.id,
        type: widget.draft.type,
        config: config,
        required: _required,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppStrings strings = AppStrings.of(context);
    final ThemeData theme = Theme.of(context);
    final MissionType type = widget.draft.type;
    return AlertDialog(
      title: Text(widget.isNew ? strings.missionAdd : strings.missionEdit),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              missionTypeName(strings, type),
              style: theme.textTheme.titleSmall,
            ),
            const SizedBox(height: 12),
            ..._fields(strings, type),
            const SizedBox(height: 8),
            SwitchListTile(
              key: const Key('mission_config_required'),
              title: Text(strings.missionRequired),
              subtitle: Text(
                _required ? strings.missionRequired : strings.missionOptional,
              ),
              value: _required,
              onChanged: (bool value) => setState(() => _required = value),
            ),
            if (_errorKey != null) ...<Widget>[
              const SizedBox(height: 8),
              Text(
                strings.text(_errorKey!),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            ],
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(strings.cancel),
        ),
        FilledButton(
          key: const Key('mission_config_save'),
          onPressed: _save,
          child: Text(strings.save),
        ),
      ],
    );
  }

  List<Widget> _fields(AppStrings strings, MissionType type) {
    switch (type) {
      case MissionType.typing:
        return <Widget>[
          _textField(strings.typingExpectedLabel, kTypingMaxLength),
        ];
      case MissionType.photo:
        return <Widget>[
          _textField(strings.photoLabel, kPhotoLabelMaxLength),
        ];
      case MissionType.qr:
        return <Widget>[
          _textField(strings.qrValueLabel, kQrValueMaxLength),
        ];
      case MissionType.barcode:
        return <Widget>[
          _textField(strings.barcodeValueLabel, kBarcodeValueMaxLength),
        ];
      case MissionType.shake:
        return <Widget>[
          Text(strings.shakeCountLabel),
          const SizedBox(height: 8),
          _countChips(
            <int>{...kShakeCountOptions, _count}.toList()..sort(),
          ),
        ];
      case MissionType.math:
        return <Widget>[
          Text(strings.mathDifficultyLabel),
          const SizedBox(height: 8),
          DropdownButton<MathDifficulty>(
            key: const Key('mission_config_difficulty'),
            value: _difficulty,
            items: <DropdownMenuItem<MathDifficulty>>[
              for (final MathDifficulty difficulty in MathDifficulty.values)
                DropdownMenuItem<MathDifficulty>(
                  value: difficulty,
                  child: Text(mathDifficultyName(strings, difficulty)),
                ),
            ],
            onChanged: (MathDifficulty? value) {
              if (value != null) {
                setState(() => _difficulty = value);
              }
            },
          ),
          const SizedBox(height: 12),
          Text(strings.mathCountLabel),
          const SizedBox(height: 8),
          _countChips(
            <int>{...kMathCountOptions, _count}.toList()..sort(),
          ),
        ];
      case MissionType.none:
        return <Widget>[Text(strings.msgMissionInvalid)];
    }
  }

  Widget _textField(String label, int maxLength) {
    return TextField(
      key: const Key('mission_config_text'),
      controller: _textController,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      maxLength: maxLength,
      onChanged: (_) {
        if (_errorKey != null) {
          setState(() => _errorKey = null);
        }
      },
    );
  }

  Widget _countChips(List<int> options) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: <Widget>[
        for (final int option in options)
          ChoiceChip(
            label: Text('$option'),
            selected: _count == option,
            onSelected: (_) => setState(() => _count = option),
          ),
      ],
    );
  }
}
