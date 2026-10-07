// Real AlarmX Home screen: the user's alarm list (Phase 3).
//
// Replaces the temporary native-pipeline test screen. Home renders the
// `watchAlarms()` stream (reactive refresh after create/edit/delete/
// toggle with no polling), and routes every mutation through
// [AlarmController] — it performs no scheduling, no trigger math, and no
// direct native calls of its own.
//
// Outcomes: save flows (returning from the editor) always confirm with a
// SnackBar; inline toggle/delete stay silent on success and report errors
// with a SnackBar. Enabled state refresh comes from the stream, so the UI
// can never disagree with the database.

import 'package:alarmx/core/alarms/alarm_controller.dart';
import 'package:alarmx/core/database/database.dart';
import 'package:alarmx/core/l10n/app_strings.dart';
import 'package:alarmx/features/alarm_editor/alarm_editor_screen.dart';
import 'package:alarmx/features/home/widgets/alarm_list_tile.dart';
import 'package:flutter/material.dart';

/// Home / alarm list; see the file docs.
class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.controller,
    required this.languageCode,
    required this.onLanguageChanged,
  });

  /// UI-to-engine bridge for all alarm operations.
  final AlarmController controller;

  /// Active UI language code ('ar'/'en'), for the menu checkmark.
  final String languageCode;

  /// Called when the user picks a language; the app shell persists it.
  final ValueChanged<String> onLanguageChanged;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  /// Alarm ids with an in-flight toggle, ignoring repeat taps.
  final Set<int> _busyToggleIds = <int>{};

  Future<void> _openCreate() async {
    final AlarmUiResult? result = await Navigator.of(context).push(
      MaterialPageRoute<AlarmUiResult>(
        builder: (_) => AlarmEditorScreen.create(
          controller: widget.controller,
        ),
      ),
    );
    if (!mounted || result == null) {
      return;
    }
    _showResult(result);
  }

  Future<void> _openEdit(Alarm alarm) async {
    final AlarmUiResult? result = await Navigator.of(context).push(
      MaterialPageRoute<AlarmUiResult>(
        builder: (_) => AlarmEditorScreen.edit(
          controller: widget.controller,
          alarmId: alarm.id,
        ),
      ),
    );
    if (!mounted || result == null) {
      return;
    }
    _showResult(result);
  }

  Future<void> _onToggle(Alarm alarm, bool value) async {
    if (value == alarm.enabled || !_busyToggleIds.add(alarm.id)) {
      return;
    }
    try {
      final AlarmUiResult result =
          await widget.controller.setEnabled(alarm.id, value);
      if (!mounted) {
        return;
      }
      if (!result.ok) {
        _showResult(result);
      }
    } finally {
      _busyToggleIds.remove(alarm.id);
    }
  }

  Future<void> _onDelete(Alarm alarm) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        final AppStrings dialogStrings = AppStrings.of(dialogContext);
        return AlertDialog(
          title: Text(dialogStrings.deleteTitle),
          content: Text(dialogStrings.deleteMessage),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(dialogStrings.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(dialogStrings.delete),
            ),
          ],
        );
      },
    );
    if (confirmed != true || !mounted) {
      return;
    }
    final AlarmUiResult result =
        await widget.controller.deleteAlarm(alarm.id);
    if (!mounted) {
      return;
    }
    if (!result.ok) {
      _showResult(result);
    }
  }

  void _showResult(AlarmUiResult result) {
    final AppStrings strings = AppStrings.of(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(strings.text(result.messageKey))),
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppStrings strings = AppStrings.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(strings.homeTitle),
        actions: <Widget>[
          PopupMenuButton<String>(
            icon: const Icon(Icons.language),
            tooltip: strings.languageMenu,
            onSelected: widget.onLanguageChanged,
            itemBuilder: (BuildContext menuContext) {
              final AppStrings menuStrings = AppStrings.of(menuContext);
              return <PopupMenuEntry<String>>[
                CheckedPopupMenuItem<String>(
                  value: AppLanguage.arabic,
                  checked:
                      widget.languageCode == AppLanguage.arabic,
                  child: Text(menuStrings.langArabic),
                ),
                CheckedPopupMenuItem<String>(
                  value: AppLanguage.english,
                  checked:
                      widget.languageCode == AppLanguage.english,
                  child: Text(menuStrings.langEnglish),
                ),
              ];
            },
          ),
        ],
      ),
      body: StreamBuilder<List<Alarm>>(
        stream: widget.controller.watchAlarms(),
        builder: (BuildContext context, AsyncSnapshot<List<Alarm>> snapshot) {
          if (snapshot.hasError) {
            return _ErrorState(
              message: strings.msgLoadFailed,
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final List<Alarm> alarms = snapshot.data!;
          if (alarms.isEmpty) {
            return _EmptyState(onAdd: _openCreate);
          }
          return ListView.builder(
            padding: const EdgeInsetsDirectional.only(
              top: 6,
              bottom: 88,
            ),
            itemCount: alarms.length,
            itemBuilder: (BuildContext context, int index) {
              final Alarm alarm = alarms[index];
              return AlarmListTile(
                alarm: alarm,
                onTap: () => _openEdit(alarm),
                onToggle: (bool value) => _onToggle(alarm, value),
                onDelete: () => _onDelete(alarm),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('add_alarm_fab'),
        onPressed: _openCreate,
        icon: const Icon(Icons.add),
        label: Text(strings.addAlarm),
      ),
    );
  }
}

/// Shown when the alarm stream itself fails (database unusable).
class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(Icons.error_outline, size: 48),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

/// Shown when no alarms exist yet.
class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final AppStrings strings = AppStrings.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(Icons.alarm_off_outlined, size: 64),
            const SizedBox(height: 16),
            Text(
              strings.homeEmptyTitle,
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              strings.homeEmptySubtitle,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              key: const Key('empty_add_button'),
              onPressed: onAdd,
              icon: const Icon(Icons.add),
              label: Text(strings.addAlarm),
            ),
          ],
        ),
      ),
    );
  }
}
