// Sequence mission widget: tap the shuffled tiles in the prompted order.
//
// Renders a [SequenceMissionController]: the direction prompt, the live
// progress, the wrong-tap hint, and the tile grid. Locked-in tiles
// highlight and disable. Completion is reported exactly once.

import 'dart:math' show Random;

import 'package:alarmx/core/l10n/app_strings.dart';
import 'package:alarmx/features/missions/mission_config.dart';
import 'package:alarmx/features/missions/sequence/sequence_mission.dart';
import 'package:flutter/material.dart';

/// Executes one sequence [entry], calling [onCompleted] once on success.
class SequenceMissionWidget extends StatefulWidget {
  const SequenceMissionWidget({
    super.key,
    required this.entry,
    required this.onCompleted,
    this.random,
  });

  final MissionEntry entry;
  final VoidCallback onCompleted;

  /// Random-source override for tests; production uses an unseeded one.
  final Random? random;

  @override
  State<SequenceMissionWidget> createState() => _SequenceMissionWidgetState();
}

class _SequenceMissionWidgetState extends State<SequenceMissionWidget> {
  late final SequenceMissionController _mission;
  bool _reported = false;

  @override
  void initState() {
    super.initState();
    final MissionConfig raw = widget.entry.config;
    final SequenceMissionConfig config = raw is SequenceMissionConfig
        ? raw
        : const SequenceMissionConfig(difficulty: SequenceDifficulty.easy);
    _mission = SequenceMissionController(
      config: config,
      random: widget.random ?? Random(),
    );
    _mission.addListener(_onProgress);
  }

  @override
  void dispose() {
    _mission.removeListener(_onProgress);
    _mission.dispose();
    super.dispose();
  }

  void _onProgress() {
    if (_mission.isDone && !_reported) {
      _reported = true;
      widget.onCompleted();
    }
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppStrings strings = AppStrings.of(context);
    if (widget.entry.config is! SequenceMissionConfig) {
      return Text(strings.ringingSkippedInvalid);
    }
    final ThemeData theme = Theme.of(context);
    if (_mission.isDone) {
      return Text(
        strings.missionCompleted,
        style: theme.textTheme.titleMedium,
        textAlign: TextAlign.center,
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          _mission.direction == SequenceDirection.ascending
              ? strings.sequencePromptAsc
              : strings.sequencePromptDesc,
          style: theme.textTheme.titleMedium,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          key: const Key('sequence_progress'),
          '${strings.sequenceProgress}: ${_mission.progress} / ${_mission.total}',
          style: theme.textTheme.bodyLarge,
          textAlign: TextAlign.center,
        ),
        if (_mission.lastAttemptWrong) ...<Widget>[
          const SizedBox(height: 8),
          Text(
            strings.sequenceWrong,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.error,
            ),
            textAlign: TextAlign.center,
          ),
        ],
        const SizedBox(height: 12),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
          ),
          itemCount: _mission.tiles.length,
          itemBuilder: (BuildContext context, int index) {
            final bool found = _mission.isFound(index);
            return AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              decoration: BoxDecoration(
                color: found
                    ? theme.colorScheme.tertiaryContainer
                    : theme.colorScheme.secondaryContainer,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  key: Key('sequence_tile_$index'),
                  borderRadius: BorderRadius.circular(16),
                  onTap: found ? null : () => _mission.tap(index),
                  child: Center(
                    child: Text(
                      '${_mission.tiles[index]}',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        color: found
                            ? theme.colorScheme.onTertiaryContainer
                            : theme.colorScheme.onSecondaryContainer,
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}
