// Alarm history screen (Phase 6).
//
// Read-only list of completed alarm occurrences from the existing
// `AlarmHistory` table (single source of truth; no second store). Each
// row shows its result at a glance (icon + localized text, never color
// alone) and expands to the full occurrence: alarm, start, stop (when
// recorded), result, attempts, and snooze count.
//
// Semantics notes:
//   - Results render exactly the stored `AlarmResult`: success, failed,
//     and emergency_stop stay distinct; ongoing rows are shown as such
//     and never as successes.
//   - `attempts` renders verbatim as stored. Phase 5 never increments
//     it (rows keep the schema default 0); Phase 6 preserves that
//     meaning and does not reinterpret or recompute it.
//   - Deleted alarms keep their rows (`alarmId` is a plain integer, not
//     a FK): missing alarms render a localized fallback, never crash,
//     and are never hidden.
//   - Ordering is newest-first by `startedAt`, enforced by the query,
//     not the UI.

import 'package:alarmx/core/database/database.dart';
import 'package:alarmx/core/l10n/app_strings.dart';
import 'package:alarmx/core/models/models.dart';
import 'package:alarmx/core/repositories/alarm_history_repository.dart';
import 'package:alarmx/core/repositories/alarm_repository.dart';
import 'package:alarmx/features/home/alarm_formatters.dart';
import 'package:flutter/material.dart';

/// Reactive alarm-history list; see the file docs.
class HistoryScreen extends StatelessWidget {
  const HistoryScreen({
    super.key,
    required this.history,
    required this.alarms,
  });

  final AlarmHistoryRepository history;
  final AlarmRepository alarms;

  @override
  Widget build(BuildContext context) {
    final AppStrings strings = AppStrings.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(strings.historyTitle)),
      body: SafeArea(
        child: StreamBuilder<List<Alarm>>(
          stream: alarms.watchAlarms(),
          builder: (
            BuildContext context,
            AsyncSnapshot<List<Alarm>> alarmSnapshot,
          ) {
            if (alarmSnapshot.hasError) {
              return _ErrorState(message: strings.msgLoadFailed);
            }
            if (!alarmSnapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final Map<int, Alarm> byId = <int, Alarm>{
              for (final Alarm alarm in alarmSnapshot.data!) alarm.id: alarm,
            };
            return StreamBuilder<List<AlarmHistoryData>>(
              stream: history.watchAllHistory(),
              builder: (
                BuildContext context,
                AsyncSnapshot<List<AlarmHistoryData>> snapshot,
              ) {
                if (snapshot.hasError) {
                  return _ErrorState(message: strings.msgLoadFailed);
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final List<AlarmHistoryData> rows = snapshot.data!;
                if (rows.isEmpty) {
                  return const _EmptyState();
                }
                return ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: rows.length,
                  itemBuilder: (BuildContext context, int index) {
                    final AlarmHistoryData row = rows[index];
                    final int? alarmId = row.alarmId;
                    return _HistoryTile(
                      row: row,
                      alarm:
                          alarmId == null ? null : byId[alarmId],
                    );
                  },
                );
              },
            );
          },
        ),
      ),
    );
  }
}

/// One expandable history occurrence.
class _HistoryTile extends StatelessWidget {
  const _HistoryTile({required this.row, required this.alarm});

  final AlarmHistoryData row;
  final Alarm? alarm;

  @override
  Widget build(BuildContext context) {
    final AppStrings strings = AppStrings.of(context);
    final ThemeData theme = Theme.of(context);
    final AlarmResult result = AlarmResult.fromDbValue(row.result);
    final _Status status = _Status.of(result);
    final ColorScheme colors = theme.colorScheme;
    return Card(
      child: ExpansionTile(
        key: Key('history_tile_${row.id}'),
        leading: Icon(status.icon, color: status.color(colors)),
        title: Text(_alarmTitle(context, strings)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(_formatDateTime(context, row.startedAt)),
            Text(
              status.label(strings),
              style: theme.textTheme.bodySmall?.copyWith(
                color: status.color(colors),
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        children: <Widget>[
          _DetailRow(
            label: strings.historyStart,
            value: _formatDateTime(context, row.startedAt),
          ),
          if (row.stoppedAt != null)
            _DetailRow(
              label: strings.historyStop,
              value: _formatDateTime(context, row.stoppedAt!),
            ),
          _DetailRow(
            label: strings.historyResult,
            value: status.label(strings),
          ),
          _DetailRow(
            label: strings.historyAttempts,
            value: '${row.attempts}',
          ),
          _DetailRow(
            label: strings.historySnoozes,
            value: '${row.snoozeCount}',
          ),
        ],
      ),
    );
  }

  String _alarmTitle(BuildContext context, AppStrings strings) {
    final Alarm? current = alarm;
    if (current == null) {
      final int? alarmId = row.alarmId;
      if (alarmId == null) {
        return strings.historyUnknownAlarm;
      }
      return '${strings.historyUnknownAlarm} #$alarmId';
    }
    final String? label = current.label?.trim().isEmpty ?? true
        ? null
        : current.label!.trim();
    return label ??
        formatAlarmTime(context, current.hour, current.minute);
  }
}

/// Icon + color + label for a stored result.
class _Status {
  const _Status({
    required this.icon,
    required this.color,
    required this.label,
  });

  final IconData icon;
  final Color Function(ColorScheme) color;
  final String Function(AppStrings) label;

  static _Status of(AlarmResult result) {
    switch (result) {
      case AlarmResult.success:
        return _Status(
          icon: Icons.check_circle_outline,
          color: (ColorScheme colors) => colors.primary,
          label: (AppStrings strings) => strings.historyStatusSuccess,
        );
      case AlarmResult.failed:
        return _Status(
          icon: Icons.cancel_outlined,
          color: (ColorScheme colors) => colors.error,
          label: (AppStrings strings) => strings.historyStatusFailed,
        );
      case AlarmResult.emergencyStop:
        return _Status(
          icon: Icons.warning_outlined,
          color: (ColorScheme colors) => colors.tertiary,
          label: (AppStrings strings) => strings.historyStatusEmergency,
        );
      case AlarmResult.ongoing:
        return _Status(
          icon: Icons.schedule_outlined,
          color: (ColorScheme colors) => colors.onSurfaceVariant,
          label: (AppStrings strings) => strings.historyStatusOngoing,
        );
    }
  }
}

/// One label/value detail line (direction-aware).
class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsetsDirectional.only(
        start: 16,
        end: 16,
        bottom: 8,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          Text(label, style: theme.textTheme.bodyMedium),
          const SizedBox(width: 16),
          Flexible(
            child: Text(
              value,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final AppStrings strings = AppStrings.of(context);
    final ThemeData theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              Icons.history,
              size: 48,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 12),
            Text(
              strings.historyEmptyTitle,
              style: theme.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              strings.historyEmptySubtitle,
              style: theme.textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          message,
          style: Theme.of(context).textTheme.titleMedium,
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

/// Localized medium date + time through `MaterialLocalizations` (same
/// convention as the Home next-trigger line).
String _formatDateTime(BuildContext context, DateTime value) {
  final MaterialLocalizations material = MaterialLocalizations.of(context);
  final String date = material.formatMediumDate(value);
  final String time = material.formatTimeOfDay(
    TimeOfDay(hour: value.hour, minute: value.minute),
    alwaysUse24HourFormat: false,
  );
  return '$date $time';
}
