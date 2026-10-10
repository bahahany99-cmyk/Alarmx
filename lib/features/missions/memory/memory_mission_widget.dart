// Memory mission widget: flip cards until every pair matches.
//
// Renders a [MemoryMissionController]: the instruction, the live
// pairs/moves progress, and the card grid. Matched pairs stay revealed
// in the success color; the current reveals animate in. Completion is
// reported exactly once.

import 'dart:math' show Random;

import 'package:alarmx/core/l10n/app_strings.dart';
import 'package:alarmx/features/missions/memory/memory_mission.dart';
import 'package:alarmx/features/missions/mission_config.dart';
import 'package:flutter/material.dart';

/// Executes one memory [entry], calling [onCompleted] once on success.
class MemoryMissionWidget extends StatefulWidget {
  const MemoryMissionWidget({
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
  State<MemoryMissionWidget> createState() => _MemoryMissionWidgetState();
}

class _MemoryMissionWidgetState extends State<MemoryMissionWidget> {
  late final MemoryMissionController _mission;
  bool _reported = false;

  @override
  void initState() {
    super.initState();
    final MissionConfig raw = widget.entry.config;
    final MemoryMissionConfig config = raw is MemoryMissionConfig
        ? raw
        : const MemoryMissionConfig(difficulty: MemoryDifficulty.easy);
    _mission = MemoryMissionController(
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
    if (widget.entry.config is! MemoryMissionConfig) {
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
    final int columns = switch (_mission.cards.length) {
      <= 12 => 3,
      <= 24 => 4,
      _ => 6,
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          strings.memoryInstruction,
          style: theme.textTheme.titleMedium,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          key: const Key('memory_progress'),
          '${strings.memoryPairs}: ${_mission.matchedPairs} / '
          '${_mission.totalPairs}  •  '
          '${strings.memoryMoves}: ${_mission.moves}',
          style: theme.textTheme.bodyLarge,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
          ),
          itemCount: _mission.cards.length,
          itemBuilder: (BuildContext context, int index) {
            final bool faceUp =
                _mission.isRevealed(index) || _mission.isMatched(index);
            final bool matched = _mission.isMatched(index);
            return GestureDetector(
              key: Key('memory_card_$index'),
              onTap: () => _mission.flip(index),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                decoration: BoxDecoration(
                  color: matched
                      ? theme.colorScheme.tertiaryContainer
                      : faceUp
                          ? theme.colorScheme.primaryContainer
                          : theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                  border: faceUp
                      ? Border.all(
                          color: theme.colorScheme.primary,
                          width: 2,
                        )
                      : null,
                ),
                child: Center(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: Text(
                      faceUp ? _mission.cards[index].face : '?',
                      key: ValueKey<bool>(faceUp),
                      style: theme.textTheme.headlineSmall,
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
