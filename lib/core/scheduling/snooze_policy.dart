// Snooze domain policy (Phase 5).
//
// Centralized, pure snooze rules over the existing alarm fields
// (`snoozeEnabled`, `snoozeMinutes`, `snoozeMaxCount`):
//   - `snoozeMinutes` must fall inside [`kSnoozeMinMinutes`,
//     `kSnoozeMaxMinutes`]; zero/negative/out-of-range values are invalid
//     and snooze is refused (never silently clamped into a schedule).
//   - `snoozeMaxCount == kSnoozeUnlimited` (-1) means unlimited snoozes;
//     otherwise it is a positive cap on snoozes per episode. Any other
//     value (0, below -1) is invalid and snooze is refused.
//   - `usedCount` is the episode's consumed snoozes (from its history
//     row); a negative count is invalid and snooze is refused.
//
// The policy never touches IO: the coordinator feeds it row + history
// state and schedules through the existing pipeline on approval.

/// Minimum snooze duration in minutes.
const int kSnoozeMinMinutes = 1;

/// Maximum snooze duration in minutes.
const int kSnoozeMaxMinutes = 60;

/// Stored `snoozeMaxCount` meaning "unlimited snoozes".
const int kSnoozeUnlimited = -1;

/// Pure snooze availability rules; see the file docs.
class SnoozePolicy {
  const SnoozePolicy._();

  /// Whether [minutes] is a schedulable snooze duration.
  static bool isValidMinutes(int minutes) {
    return minutes >= kSnoozeMinMinutes && minutes <= kSnoozeMaxMinutes;
  }

  /// Whether [maxCount] is a usable snooze cap (positive) or unlimited.
  static bool isValidMaxCount(int maxCount) {
    return maxCount == kSnoozeUnlimited || maxCount >= 1;
  }

  /// Whether [maxCount] lifts the cap entirely.
  static bool isUnlimited(int maxCount) {
    return maxCount == kSnoozeUnlimited;
  }

  /// Whether one more snooze is allowed for this config + [usedCount].
  static bool canSnooze({
    required bool enabled,
    required int minutes,
    required int maxCount,
    required int usedCount,
  }) {
    if (!enabled) {
      return false;
    }
    if (!isValidMinutes(minutes)) {
      return false;
    }
    if (!isValidMaxCount(maxCount)) {
      return false;
    }
    if (usedCount < 0) {
      return false;
    }
    if (isUnlimited(maxCount)) {
      return true;
    }
    return usedCount < maxCount;
  }

  /// Snoozes left, or `null` when unlimited. Returns 0 for exhausted or
  /// invalid (non-unlimited) caps; callers check [canSnooze] first.
  static int? remainingSnoozes({
    required int maxCount,
    required int usedCount,
  }) {
    if (isUnlimited(maxCount)) {
      return null;
    }
    if (maxCount < 1 || usedCount < 0) {
      return 0;
    }
    final int remaining = maxCount - usedCount;
    return remaining < 0 ? 0 : remaining;
  }
}
