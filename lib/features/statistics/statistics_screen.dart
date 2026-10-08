import 'package:alarmx/core/database/database.dart';
import 'package:alarmx/core/l10n/app_strings.dart';
import 'package:alarmx/core/repositories/alarm_history_repository.dart';
import 'package:alarmx/core/repositories/alarm_repository.dart';
import 'package:alarmx/features/home/alarm_formatters.dart';
import 'package:alarmx/features/statistics/statistics_calculator.dart';
import 'package:flutter/material.dart';

/// Week summary over real history rows. Ar-first RTL, English-localized.
///
/// Metrics come from [computeStatistics] over the live history stream, so the
/// screen updates whenever history changes without polling. Durations use the
/// screen's own `M:SS` template; missing metrics render the localized
/// unavailable label and never a manufactured `0:00`.
class StatisticsScreen extends StatefulWidget {
  const StatisticsScreen({
    super.key,
    required this.history,
    required this.alarms,
  });

  final AlarmHistoryRepository history;
  final AlarmRepository alarms;

  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen> {
  Future<List<Alarm>>? _alarmsFuture;

  @override
  void initState() {
    super.initState();
    _alarmsFuture = widget.alarms.watchAlarms().first;
  }

  @override
  Widget build(BuildContext context) {
    final AppStrings strings = AppStrings.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(strings.statisticsTitle)),
      body: FutureBuilder<List<Alarm>>(
        future: _alarmsFuture,
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
            stream: widget.history.watchAllHistory(),
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
              // The week boundary is evaluated per build; crossing into a new
              // week refreshes on the next history event (no polling).
              final AlarmStatistics stats = computeStatistics(
                rows: snapshot.data!,
                now: DateTime.now(),
                labelFor: (int? alarmId) =>
                    _alarmLabel(context, strings, byId, alarmId),
              );
              return _StatisticsLoaded(stats: stats);
            },
          );
        },
      ),
    );
  }

  /// Display label for a history identity; never null (the calculator uses it
  /// verbatim). Missing alarms keep their rows readable via the fallback.
  String _alarmLabel(
    BuildContext context,
    AppStrings strings,
    Map<int, Alarm> byId,
    int? alarmId,
  ) {
    if (alarmId == null) {
      return strings.historyUnknownAlarm;
    }
    final Alarm? alarm = byId[alarmId];
    if (alarm == null) {
      return '${strings.historyUnknownAlarm} #$alarmId';
    }
    final String? label = alarm.label?.trim().isEmpty ?? true
        ? null
        : alarm.label!.trim();
    return label ?? formatAlarmTime(context, alarm.hour, alarm.minute);
  }
}

class _StatisticsLoaded extends StatelessWidget {
  const _StatisticsLoaded({required this.stats});

  final AlarmStatistics stats;

  @override
  Widget build(BuildContext context) {
    final AppStrings strings = AppStrings.of(context);
    final ThemeData theme = Theme.of(context);
    final String unavailable = strings.statisticsUnavailable;
    return ListView(
      padding: const EdgeInsets.all(12),
      children: <Widget>[
        _MetricCard(
          icon: Icons.check_circle_outline,
          color: theme.colorScheme.primary,
          label: strings.statisticsCompleted,
          value: '${stats.completedThisWeek}',
        ),
        _MetricCard(
          icon: Icons.cancel_outlined,
          color: theme.colorScheme.error,
          label: strings.statisticsFailed,
          value: '${stats.failedThisWeek}',
        ),
        _MetricCard(
          icon: Icons.timer_outlined,
          color: theme.colorScheme.secondary,
          label: strings.statisticsAverage,
          value: stats.averageStop == null
              ? unavailable
              : formatStopDuration(stats.averageStop!),
        ),
        _MetricCard(
          icon: Icons.bolt_outlined,
          color: theme.colorScheme.tertiary,
          label: strings.statisticsFastest,
          value: stats.fastestStop == null
              ? unavailable
              : formatStopDuration(stats.fastestStop!),
        ),
        _MetricCard(
          icon: Icons.emoji_events_outlined,
          color: theme.colorScheme.secondary,
          label: strings.statisticsHardest,
          value: stats.hardestAverage == null
              ? unavailable
              : formatStopDuration(stats.hardestAverage!),
          subtitle: stats.hardestAlarmLabel,
        ),
      ],
    );
  }
}

/// One metric: icon + label + value (text and icon, never color-only).
class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
    this.subtitle,
  });

  final IconData icon;
  final Color color;
  final String label;
  final String value;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Card(
      child: ListTile(
        leading: Icon(icon, color: color),
        title: Text(label),
        subtitle: subtitle == null ? null : Text(subtitle!),
        trailing: Text(
          value,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}

/// `M:SS` stop duration (whole seconds, truncated). The screen's own stable
/// template — never a framework date/time string, so widget tests can assert
/// it exactly in every locale.
String formatStopDuration(Duration value) {
  final int totalSeconds = value.inSeconds;
  final int minutes = totalSeconds ~/ 60;
  final int seconds = totalSeconds % 60;
  return '$minutes:${seconds.toString().padLeft(2, '0')}';
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
