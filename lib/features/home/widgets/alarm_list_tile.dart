// One alarm row on the Home screen (Phase 3).
//
// Shows time, label, repeat description, next-trigger line, an enable
// switch with a text (not color-only) on/off state, and a delete button.
// Tapping the row opens the editor. Layout uses only direction-aware
// widgets (`ListTile`, `Row`, `Column`) so RTL mirrors automatically.
//
// Accessibility: the switch carries a semantic label naming its alarm,
// the delete button has a tooltip, and enabled state is always conveyed
// by text plus switch position — dimming is only an extra cue.

import 'package:alarmx/core/database/database.dart';
import 'package:alarmx/core/l10n/app_strings.dart';
import 'package:alarmx/features/home/alarm_formatters.dart';
import 'package:flutter/material.dart';

/// Alarm card for [alarm]; see the file docs.
class AlarmListTile extends StatelessWidget {
  const AlarmListTile({
    super.key,
    required this.alarm,
    required this.onTap,
    required this.onToggle,
    required this.onDelete,
  });

  final Alarm alarm;
  final VoidCallback onTap;
  final ValueChanged<bool> onToggle;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final AppStrings strings = AppStrings.of(context);
    final String timeText =
        formatAlarmTime(context, alarm.hour, alarm.minute);
    final String? label = alarm.label?.trim().isEmpty ?? true
        ? null
        : alarm.label!.trim();
    final String stateText =
        alarm.enabled ? strings.onLabel : strings.offLabel;
    final ThemeData theme = Theme.of(context);

    // Custom row instead of ListTile: ListTile fixes its height (56/72/88)
    // by line count, but the title plus 2-3 subtitle lines exceed those
    // heights under taller font metrics and overflow. This layout sizes to
    // content in both axes, so it fits under any font metrics.
    return Opacity(
      opacity: alarm.enabled ? 1.0 : 0.55,
      child: Card(
        key: Key('alarm_tile_${alarm.id}'),
        margin: const EdgeInsetsDirectional.only(
          start: 12,
          end: 12,
          top: 6,
          bottom: 6,
        ),
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsetsDirectional.only(
              start: 16,
              end: 8,
              top: 8,
              bottom: 8,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(
                        timeText,
                        style: theme.textTheme.headlineMedium,
                      ),
                      const SizedBox(height: 4),
                      if (label != null)
                        Text(label, style: theme.textTheme.titleMedium),
                      Text(describeRepeat(context, alarm)),
                      Text(describeNextTrigger(context, alarm)),
                    ],
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    Semantics(
                      label: label == null
                          ? '$timeText, $stateText'
                          : '$timeText, $label, $stateText',
                      child: Switch(
                        key: Key('alarm_toggle_${alarm.id}'),
                        value: alarm.enabled,
                        onChanged: onToggle,
                      ),
                    ),
                    Text(stateText, style: theme.textTheme.bodySmall),
                  ],
                ),
                IconButton(
                  key: Key('alarm_delete_${alarm.id}'),
                  icon: const Icon(Icons.delete_outline),
                  tooltip: strings.delete,
                  onPressed: onDelete,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
