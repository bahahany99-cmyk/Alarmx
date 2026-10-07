// PIN prompt dialog (Phase 5).
//
// Small obscured numeric entry used everywhere the app gates a
// protected action on the PIN (strict changes, protected deletes,
// mission unlocks, emergency PIN). Returns the entered PIN, or `null`
// when cancelled/dismissed. Verification belongs to the caller
// ([PinService]); this dialog never sees the stored hash.
//
// The entry lives in a stateful dialog that owns its controller: the
// controller must stay alive until the dialog element unmounts (after
// the pop transition), so disposing it from the popped future would be
// a use-after-dispose.

import 'package:alarmx/core/l10n/app_strings.dart';
import 'package:alarmx/core/security/pin_service.dart';
import 'package:flutter/material.dart';

/// Asks for the PIN; see the file docs.
Future<String?> showPinPrompt(
  BuildContext context, {
  required String title,
  String? label,
}) {
  return showDialog<String>(
    context: context,
    builder: (_) => _PinPromptDialog(title: title, label: label),
  );
}

/// Obscured PIN entry; owns its controller for its whole lifetime.
class _PinPromptDialog extends StatefulWidget {
  const _PinPromptDialog({required this.title, this.label});

  final String title;
  final String? label;

  @override
  State<_PinPromptDialog> createState() => _PinPromptDialogState();
}

class _PinPromptDialogState extends State<_PinPromptDialog> {
  late final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppStrings strings = AppStrings.of(context);
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        key: const Key('pin_prompt_field'),
        controller: _controller,
        decoration: InputDecoration(
          labelText: widget.label ?? strings.pinEnter,
          border: const OutlineInputBorder(),
        ),
        obscureText: true,
        keyboardType: TextInputType.number,
        maxLength: kPinMaxLength,
        autofocus: true,
        onSubmitted: (_) =>
            Navigator.of(context).pop(_controller.text),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(strings.cancel),
        ),
        FilledButton(
          key: const Key('pin_prompt_confirm'),
          onPressed: () => Navigator.of(context).pop(_controller.text),
          child: Text(strings.pinConfirm),
        ),
      ],
    );
  }
}
