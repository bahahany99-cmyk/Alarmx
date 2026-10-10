// Scroll-wheel time picker dialog (alarm-editor refresh).
//
// Replaces the circular clock picker with three vertical wheels (hour,
// minute, AM/PM). The dialog owns only selection state: it opens on
// [initialTime], reports the picked [TimeOfDay] through the dialog
// result, and optionally shows a live "time remaining" preview at the
// bottom via [remainingText], which the caller recomputes for every
// candidate position (the dialog itself does no schedule math).

import 'package:alarmx/core/l10n/app_strings.dart';
import 'package:flutter/material.dart';

/// Height of one wheel row; three rows show above/below the selector.
const double kTimeWheelItemExtent = 48;

/// Opens the wheel picker. Returns the picked time, or null on cancel.
Future<TimeOfDay?> showTimeWheelPicker({
  required BuildContext context,
  required TimeOfDay initialTime,
  String Function(TimeOfDay candidate)? remainingText,
}) {
  return showDialog<TimeOfDay>(
    context: context,
    builder: (BuildContext context) => _TimeWheelDialog(
      initialTime: initialTime,
      remainingText: remainingText,
    ),
  );
}

class _TimeWheelDialog extends StatefulWidget {
  const _TimeWheelDialog({
    required this.initialTime,
    required this.remainingText,
  });

  final TimeOfDay initialTime;
  final String Function(TimeOfDay candidate)? remainingText;

  @override
  State<_TimeWheelDialog> createState() => _TimeWheelDialogState();
}

class _TimeWheelDialogState extends State<_TimeWheelDialog> {
  late int _hour12 = widget.initialTime.hourOfPeriod == 0
      ? 12
      : widget.initialTime.hourOfPeriod;
  late int _minute = widget.initialTime.minute;
  late DayPeriod _period = widget.initialTime.period;

  late final FixedExtentScrollController _hourController =
      FixedExtentScrollController(initialItem: _hour12 - 1);
  late final FixedExtentScrollController _minuteController =
      FixedExtentScrollController(initialItem: _minute);
  late final FixedExtentScrollController _periodController =
      FixedExtentScrollController(
        initialItem: _period == DayPeriod.am ? 0 : 1,
      );

  @override
  void dispose() {
    _hourController.dispose();
    _minuteController.dispose();
    _periodController.dispose();
    super.dispose();
  }

  TimeOfDay get _candidate {
    final int hour24 = _period == DayPeriod.am
        ? _hour12 % 12
        : (_hour12 % 12) + 12;
    return TimeOfDay(hour: hour24, minute: _minute);
  }

  @override
  Widget build(BuildContext context) {
    final AppStrings strings = AppStrings.of(context);
    final ThemeData theme = Theme.of(context);
    final String Function(TimeOfDay candidate)? preview = widget.remainingText;
    return AlertDialog(
      title: Text(strings.timePickerTitle),
      content: SizedBox(
        width: 280,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            SizedBox(
              height: kTimeWheelItemExtent * 4,
              child: Stack(
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: _wheel(
                          key: const Key('time_wheel_hour'),
                          controller: _hourController,
                          itemCount: 12,
                          selected: _hour12 - 1,
                          label: (int index) => '${index + 1}',
                          onSelected: (int index) =>
                              setState(() => _hour12 = index + 1),
                        ),
                      ),
                      Text(
                        ':',
                        style: theme.textTheme.headlineMedium,
                      ),
                      Expanded(
                        child: _wheel(
                          key: const Key('time_wheel_minute'),
                          controller: _minuteController,
                          itemCount: 60,
                          selected: _minute,
                          label: (int index) =>
                              index.toString().padLeft(2, '0'),
                          onSelected: (int index) =>
                              setState(() => _minute = index),
                        ),
                      ),
                      Expanded(
                        child: _wheel(
                          key: const Key('time_wheel_period'),
                          controller: _periodController,
                          itemCount: 2,
                          selected:
                              _period == DayPeriod.am ? 0 : 1,
                          label: (int index) => index == 0
                              ? strings.periodAm
                              : strings.periodPm,
                          onSelected: (int index) => setState(
                            () => _period = index == 0
                                ? DayPeriod.am
                                : DayPeriod.pm,
                          ),
                        ),
                      ),
                    ],
                  ),
                  // Center selection band (decorative; the wheels own
                  // the actual selection state).
                  IgnorePointer(
                    child: Center(
                      child: Container(
                        height: kTimeWheelItemExtent,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primaryContainer
                              .withValues(alpha: 0.35),
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (preview != null) ...<Widget>[
              const SizedBox(height: 12),
              Row(
                key: const Key('time_wheel_remaining'),
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Icon(
                    Icons.timelapse,
                    size: 18,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      '${strings.editorRemaining}: ${preview(_candidate)}',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          key: const Key('time_wheel_cancel'),
          onPressed: () => Navigator.of(context).pop(),
          child: Text(strings.cancel),
        ),
        FilledButton(
          key: const Key('time_wheel_set'),
          onPressed: () => Navigator.of(context).pop(_candidate),
          child: Text(strings.save),
        ),
      ],
    );
  }

  /// One wheel column. The selected row renders emphasized; the rest
  /// dimmed, so the current value reads at a glance.
  Widget _wheel({
    required Key key,
    required FixedExtentScrollController controller,
    required int itemCount,
    required int selected,
    required String Function(int index) label,
    required ValueChanged<int> onSelected,
  }) {
    final ThemeData theme = Theme.of(context);
    return ListWheelScrollView.useDelegate(
      key: key,
      controller: controller,
      itemExtent: kTimeWheelItemExtent,
      diameterRatio: 1.4,
      useMagnifier: true,
      magnification: 1.15,
      physics: const FixedExtentScrollPhysics(),
      onSelectedItemChanged: onSelected,
      childDelegate: ListWheelChildBuilderDelegate(
        childCount: itemCount,
        builder: (BuildContext context, int index) {
          final bool isSelected = index == selected;
          return Center(
            child: Text(
              label(index),
              style: (isSelected
                      ? theme.textTheme.headlineSmall
                      : theme.textTheme.bodyLarge)
                  ?.copyWith(
                color: isSelected
                    ? theme.colorScheme.onSurface
                    : theme.colorScheme.onSurfaceVariant
                        .withValues(alpha: 0.6),
                fontWeight:
                    isSelected ? FontWeight.w700 : FontWeight.w400,
              ),
            ),
          );
        },
      ),
    );
  }
}
