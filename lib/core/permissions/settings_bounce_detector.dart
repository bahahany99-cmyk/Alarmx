// Shared settings-bounce detector.
//
// Some OEM skins resolve a Settings deep link and launch it, then the
// Settings page immediately finishes itself — the user never reaches a
// toggle while the native launch reports success. The native layer cannot
// observe this; only the app's own lifecycle can: [arm] records when a
// settings launch reported launched=true, and [consumeResume] judges the
// next resume by how long the user was away.
//
// Extracted from the Permission Center screen so onboarding reuses the
// exact same detection (threshold included); behavior there is unchanged.

/// Judges settings launches as genuine visits or instant bounces.
class SettingsBounceDetector {
  SettingsBounceDetector({
    DateTime Function()? clock,
    this.threshold = const Duration(milliseconds: 1500),
  }) : _clock = clock ?? DateTime.now;

  /// A settings visit shorter than this is judged a bounce: the target
  /// page closed (near-)instantly instead of hosting the user (observed
  /// on OEM skins that resolve-but-kill certain deep links, well under
  /// 1s). Far below any genuine visit, so normal use never trips it.
  final Duration threshold;

  final DateTime Function() _clock;

  /// When the last settings launch reported launched=true, awaiting its
  /// resume verdict. Consumed (nulled) by [consumeResume].
  DateTime? _launchedAt;

  /// Arms the detector. Call exactly when a settings launch reports
  /// launched=true (never for failed launches or runtime dialogs).
  void arm() {
    _launchedAt = _clock();
  }

  /// Judges one resume against the armed launch. Returns true when the
  /// app resumed within [threshold] of the launch (a bounce). Consumes
  /// the armed stamp exactly once, so each launch gets one verdict and
  /// resumes with no armed launch report no bounce.
  bool consumeResume() {
    final DateTime? launchedAt = _launchedAt;
    _launchedAt = null;
    if (launchedAt == null) {
      return false;
    }
    return _clock().difference(launchedAt) < threshold;
  }
}
