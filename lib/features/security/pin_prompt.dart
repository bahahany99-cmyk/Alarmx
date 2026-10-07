// PIN prompt dialog (Phase 5).
//
// Small obscured numeric entry used everywhere the app gates a
// protected action on the PIN (strict changes, protected deletes,
// mission unlocks, emergency PIN). Returns the entered PIN, or `null`
// when cancelled/dismissed. Verification belongs to the caller
// ([PinService]); this dialog never sees the stored hash.

import 'package:alarmx/core/l10n/app_strings.dart';
import 'package:alarmx/core/security/pin_service.dart';
import 'package:flutter/material.dart';

/// Asks for the PIN; see the file docs.
Future<String?> showPinPrompt(
  BuildContext context, {
  required String title,
  String? label,
}) {
  final TextEditingController controller = TextEditingController();
  return showDialog<String>(
    context: context,
    builder: (BuildContext dialogContext) {
      final AppStrings strings = AppStrings.of(dialogContext);
      return AlertDialog(
        title: Text(title),
        content: TextField(
          key: const Key('pin_prompt_field'),
          controller: controller,
          decoration: InputDecoration(
            labelText: label ?? strings.pinEnter,
            border: const OutlineInputBorder(),
          ),
          obscureText: true,
          keyboardType: TextInputType.number,
          maxLength: kPinMaxLength,
          autofocus: true,
          onSubmitted: (_) =>
              Navigator.of(dialogContext).pop(controller.text),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(strings.cancel),
          ),
          FilledButton(
            key: const Key('pin_prompt_confirm'),
            onPressed: () =>
                Navigator.of(dialogContext).pop(controller.text),
            child: Text(strings.pinConfirm),
          ),
        ],
      );
    },
  ).whenComplete(controller.dispose);
}
