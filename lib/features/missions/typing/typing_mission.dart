// Typing mission logic (Phase 4): deterministic answer checking.
//
// The user retypes the shown [TypingMissionConfig.expectedText].
// Comparison is exact after trimming surrounding whitespace on BOTH sides:
// case and inner spacing must match what is shown. Empty input (or an
// empty expected text, which validation forbids) never succeeds.

import '../mission_config.dart';

/// Checks a typed answer against [config]; see the file docs.
bool checkTypingAnswer(TypingMissionConfig config, String input) {
  final String expected = config.expectedText.trim();
  if (expected.isEmpty) {
    return false;
  }
  return input.trim() == expected;
}
