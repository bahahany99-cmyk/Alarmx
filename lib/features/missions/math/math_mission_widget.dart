// Math mission widget (Phase 4): solve every generated question.
//
// Renders a [MathMissionController]: progress (`Mission i / N`), the
// current question, an integer input, and a Solve button. A wrong answer
// shows the failure state and keeps the question; solving the last
// question completes exactly once (the button disables on success, so
// accidental double-submission cannot report twice).

import 'dart:math' show Random;

import 'package:alarmx/core/l10n/app_strings.dart';
import 'package:alarmx/features/missions/math/math_mission.dart';
import 'package:alarmx/features/missions/mission_config.dart';
import 'package:flutter/material.dart';

/// Executes one math [entry], calling [onCompleted] once on success.
class MathMissionWidget extends StatefulWidget {
  const MathMissionWidget({
    super.key,
    required this.entry,
    required this.onCompleted,
    this.random,
  });

  final MissionEntry entry;
  final VoidCallback onCompleted;

  /// Random-source override for tests; production uses a live one.
  final Random? random;

  @override
  State<MathMissionWidget> createState() => _MathMissionWidgetState();
}

class _MathMissionWidgetState extends State<MathMissionWidget> {
  late final MathMissionController _mission;
  late final TextEditingController _answer = TextEditingController();
  bool _done = false;

  @override
  void initState() {
    super.initState();
    final MissionConfig raw = widget.entry.config;
    _mission = MathMissionController(
      config: raw is MathMissionConfig
          ? raw
          : const MathMissionConfig(
              questionCount: 1,
              difficulty: MathDifficulty.easy,
            ),
      random: widget.random ?? Random(),
    );
  }

  @override
  void dispose() {
    _mission.dispose();
    _answer.dispose();
    super.dispose();
  }

  void _submit() {
    if (_done) {
      return;
    }
    final bool completed = _mission.submit(_answer.text);
    if (completed) {
      setState(() {
        _done = true;
      });
      _answer.clear();
      widget.onCompleted();
    } else if (!_mission.lastAttemptFailed) {
      // Advanced to the next question: clear the input for it.
      _answer.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppStrings strings = AppStrings.of(context);
    if (widget.entry.config is! MathMissionConfig) {
      return Text(strings.ringingSkippedInvalid);
    }
    final ThemeData theme = Theme.of(context);
    return ListenableBuilder(
      listenable: _mission,
      builder: (BuildContext context, Widget? _) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              strings.mathInstruction,
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              '${strings.missionProgress} ${_mission.index + 1} / ${_mission.total}',
              style: theme.textTheme.bodyLarge,
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  _mission.current.display(),
                  style: theme.textTheme.headlineSmall,
                  textAlign: TextAlign.center,
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('math_answer_field'),
              controller: _answer,
              enabled: !_done,
              decoration: InputDecoration(
                labelText: strings.mathAnswerHint,
                border: const OutlineInputBorder(),
                errorText:
                    _mission.lastAttemptFailed ? strings.missionIncorrect : null,
              ),
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: 12),
            FilledButton(
              key: const Key('math_solve_button'),
              onPressed: _done ? null : _submit,
              child: Text(
                _done ? strings.missionCompleted : strings.missionSolve,
              ),
            ),
          ],
        );
      },
    );
  }
}
