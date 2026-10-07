// Typing mission widget (Phase 4): retype the shown text.
//
// Shows the instruction, the expected text, an input, and a Check button.
// A wrong answer shows the failure state and stays on the mission; a
// correct answer completes exactly once (the button and field disable on
// success, so accidental double-submission cannot report twice).

import 'package:alarmx/core/l10n/app_strings.dart';
import 'package:alarmx/features/missions/mission_config.dart';
import 'package:alarmx/features/missions/typing/typing_mission.dart';
import 'package:flutter/material.dart';

/// Executes one typing [entry], calling [onCompleted] once on success.
class TypingMissionWidget extends StatefulWidget {
  const TypingMissionWidget({
    super.key,
    required this.entry,
    required this.onCompleted,
  });

  final MissionEntry entry;
  final VoidCallback onCompleted;

  @override
  State<TypingMissionWidget> createState() => _TypingMissionWidgetState();
}

class _TypingMissionWidgetState extends State<TypingMissionWidget> {
  late final TextEditingController _controller = TextEditingController();
  bool _failed = false;
  bool _done = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _check(TypingMissionConfig config) {
    if (_done) {
      return;
    }
    if (checkTypingAnswer(config, _controller.text)) {
      setState(() {
        _done = true;
        _failed = false;
      });
      widget.onCompleted();
    } else {
      setState(() {
        _failed = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppStrings strings = AppStrings.of(context);
    final MissionConfig raw = widget.entry.config;
    if (raw is! TypingMissionConfig) {
      return Text(strings.ringingSkippedInvalid);
    }
    final TypingMissionConfig config = raw;
    final ThemeData theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          strings.typingInstruction,
          style: theme.textTheme.titleMedium,
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              config.expectedText.trim(),
              style: theme.textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          key: const Key('typing_answer_field'),
          controller: _controller,
          enabled: !_done,
          decoration: InputDecoration(
            labelText: strings.typingHint,
            border: const OutlineInputBorder(),
            errorText: _failed ? strings.missionIncorrect : null,
          ),
          textInputAction: TextInputAction.done,
          maxLength: kTypingMaxLength,
          onSubmitted: (_) => _check(config),
        ),
        const SizedBox(height: 12),
        FilledButton(
          key: const Key('typing_check_button'),
          onPressed: _done ? null : () => _check(config),
          child: Text(_done ? strings.missionCompleted : strings.missionCheck),
        ),
      ],
    );
  }
}
