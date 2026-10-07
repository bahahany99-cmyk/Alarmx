// Mission domain model (Phase 4).
//
// The Drift `Mission` row stays the storage shape (see `core/models/`:
// no duplicated entity layer). This file adds what the row cannot express
// on its own:
//
//   - [MissionConfig]: the typed reading of the `configJson` column, one
//     subtype per executable [MissionType]. Exactly the roadmap contract,
//     nothing more: typing text, photo label, QR value, barcode value,
//     shake count, math count + difficulty.
//   - [parseMissionConfig] / [encodeMissionConfig]: the single JSON
//     boundary. Unknown fields are ignored (version-tolerant); anything
//     else malformed yields `null` instead of throwing, so corrupt rows
//     can be skipped with a warning and never crash the alarm UI.
//   - [MissionDraft]: editor-side mutable mission (create/edit/delete/
//     reorder work on drafts; the service persists them atomically).
//   - [MissionEntry]: a validated executable mission for the engine.
//
// Comparison/validation rules (kept identical in tests):
//   - Text configs are validated trimmed; an all-whitespace value is empty.
//   - `MissionType.none` rows are inert: never executable, never an error.

import 'dart:convert';

import 'package:alarmx/core/database/database.dart';
import 'package:alarmx/core/models/models.dart';

/// Maximum stored length of the typing mission's expected text.
const int kTypingMaxLength = 120;

/// Maximum stored length of the photo mission's optional label.
const int kPhotoLabelMaxLength = 120;

/// Maximum stored length of a QR expected value.
const int kQrValueMaxLength = 512;

/// Maximum stored length of a barcode expected value.
const int kBarcodeValueMaxLength = 128;

/// Valid shake-count range (editor offers fixed choices inside it).
const int kShakeMinCount = 1;
const int kShakeMaxCount = 50;

/// Valid math question-count range (editor offers fixed choices inside it).
const int kMathMinCount = 1;
const int kMathMaxCount = 20;

/// Fixed shake-count choices offered by the mission editor.
const List<int> kShakeCountOptions = <int>[5, 10, 15, 20, 30];

/// Fixed math question-count choices offered by the mission editor.
const List<int> kMathCountOptions = <int>[3, 5, 10];

/// Math mission difficulty, stored as [dbValue] inside the config JSON.
enum MathDifficulty {
  easy('easy'),
  medium('medium'),
  hard('hard');

  const MathDifficulty(this.dbValue);

  /// Exact string stored in the config JSON.
  final String dbValue;

  /// Decodes a stored value; unknown values yield `null` (invalid config)
  /// instead of silently downgrading the mission a user configured.
  static MathDifficulty? fromDbValue(String? value) {
    for (final MathDifficulty difficulty in MathDifficulty.values) {
      if (difficulty.dbValue == value) {
        return difficulty;
      }
    }
    return null;
  }
}

/// Typed mission configuration; see the file docs.
sealed class MissionConfig {
  const MissionConfig();

  /// The mission type this config belongs to.
  MissionType get type;

  /// Serializes to the JSON map stored in `configJson`.
  Map<String, Object?> toJson();

  /// Structural validation key, or `null` when the config can be saved.
  /// Returns an [AppStrings] message key, not display text.
  String? validationMessageKey();
}

/// Typing mission: retype [expectedText] (shown to the user at execution).
///
/// Comparison is exact after trimming surrounding whitespace: case and
/// inner spacing must match what is shown.
class TypingMissionConfig extends MissionConfig {
  const TypingMissionConfig(this.expectedText);

  final String expectedText;

  @override
  MissionType get type => MissionType.typing;

  @override
  Map<String, Object?> toJson() => <String, Object?>{
        'text': expectedText.trim(),
      };

  @override
  String? validationMessageKey() {
    final String trimmed = expectedText.trim();
    if (trimmed.isEmpty || trimmed.length > kTypingMaxLength) {
      return 'missionFieldRequired';
    }
    return null;
  }
}

/// Photo mission: capture a photo with the system camera to dismiss.
///
/// Phase 4 validates capture completion, not image similarity: local
/// computer-vision matching is explicitly deferred to the later V1.1/V2
/// enhancement. [label] is an optional free-text hint shown to the user
/// (e.g. what to photograph); it is never used for matching.
class PhotoMissionConfig extends MissionConfig {
  const PhotoMissionConfig([this.label = '']);

  final String label;

  @override
  MissionType get type => MissionType.photo;

  @override
  Map<String, Object?> toJson() => <String, Object?>{
        'label': label.trim(),
      };

  @override
  String? validationMessageKey() {
    if (label.trim().length > kPhotoLabelMaxLength) {
      return 'missionFieldRequired';
    }
    return null;
  }
}

/// QR mission: scan the code whose value is [expectedValue].
///
/// Comparison is exact after trimming surrounding whitespace.
class QrMissionConfig extends MissionConfig {
  const QrMissionConfig(this.expectedValue);

  final String expectedValue;

  @override
  MissionType get type => MissionType.qr;

  @override
  Map<String, Object?> toJson() => <String, Object?>{
        'value': expectedValue.trim(),
      };

  @override
  String? validationMessageKey() {
    final String trimmed = expectedValue.trim();
    if (trimmed.isEmpty || trimmed.length > kQrValueMaxLength) {
      return 'missionFieldRequired';
    }
    return null;
  }
}

/// Barcode mission: scan the code whose value is [expectedValue].
///
/// Comparison is exact after trimming surrounding whitespace.
class BarcodeMissionConfig extends MissionConfig {
  const BarcodeMissionConfig(this.expectedValue);

  final String expectedValue;

  @override
  MissionType get type => MissionType.barcode;

  @override
  Map<String, Object?> toJson() => <String, Object?>{
        'value': expectedValue.trim(),
      };

  @override
  String? validationMessageKey() {
    final String trimmed = expectedValue.trim();
    if (trimmed.isEmpty || trimmed.length > kBarcodeValueMaxLength) {
      return 'missionFieldRequired';
    }
    return null;
  }
}

/// Shake mission: reach [requiredCount] valid shakes.
class ShakeMissionConfig extends MissionConfig {
  const ShakeMissionConfig(this.requiredCount);

  final int requiredCount;

  @override
  MissionType get type => MissionType.shake;

  @override
  Map<String, Object?> toJson() => <String, Object?>{
        'count': requiredCount,
      };

  @override
  String? validationMessageKey() {
    if (requiredCount < kShakeMinCount || requiredCount > kShakeMaxCount) {
      return 'missionFieldRequired';
    }
    return null;
  }
}

/// Math mission: solve [questionCount] questions at [difficulty].
class MathMissionConfig extends MissionConfig {
  const MathMissionConfig({
    required this.questionCount,
    required this.difficulty,
  });

  final int questionCount;
  final MathDifficulty difficulty;

  @override
  MissionType get type => MissionType.math;

  @override
  Map<String, Object?> toJson() => <String, Object?>{
        'count': questionCount,
        'difficulty': difficulty.dbValue,
      };

  @override
  String? validationMessageKey() {
    if (questionCount < kMathMinCount || questionCount > kMathMaxCount) {
      return 'missionFieldRequired';
    }
    return null;
  }
}

/// Parses [configJson] into the config for [type], or `null` when the
/// stored value is missing/malformed. Never throws: unknown JSON fields
/// are ignored, and every structural problem (bad JSON, wrong shape,
/// wrong field types) yields `null` so the caller can skip the row with
/// a warning instead of crashing.
///
/// `MissionType.none` has no config and always yields `null`.
MissionConfig? parseMissionConfig(MissionType type, String? configJson) {
  if (type == MissionType.none) {
    return null;
  }
  if (configJson == null || configJson.trim().isEmpty) {
    // Only the photo mission tolerates a missing config: its label is
    // optional, so an absent JSON object equals the default config.
    return type == MissionType.photo ? const PhotoMissionConfig() : null;
  }
  final Object? decoded;
  try {
    decoded = jsonDecode(configJson);
  } catch (_) {
    return null;
  }
  if (decoded is! Map<String, Object?>) {
    return null;
  }
  switch (type) {
    case MissionType.none:
      return null;
    case MissionType.typing:
      final Object? text = decoded['text'];
      return text is String ? TypingMissionConfig(text) : null;
    case MissionType.photo:
      final Object? label = decoded['label'];
      if (label == null) {
        return const PhotoMissionConfig();
      }
      return label is String ? PhotoMissionConfig(label) : null;
    case MissionType.qr:
      final Object? value = decoded['value'];
      return value is String ? QrMissionConfig(value) : null;
    case MissionType.barcode:
      final Object? value = decoded['value'];
      return value is String ? BarcodeMissionConfig(value) : null;
    case MissionType.shake:
      final Object? count = decoded['count'];
      return count is int ? ShakeMissionConfig(count) : null;
    case MissionType.math:
      final Object? count = decoded['count'];
      final Object? difficulty = decoded['difficulty'];
      final MathDifficulty? parsedDifficulty =
          difficulty is String ? MathDifficulty.fromDbValue(difficulty) : null;
      if (count is! int || parsedDifficulty == null) {
        return null;
      }
      return MathMissionConfig(
        questionCount: count,
        difficulty: parsedDifficulty,
      );
  }
}

/// Serializes [config] to the string stored in `configJson`.
String encodeMissionConfig(MissionConfig config) {
  return jsonEncode(config.toJson());
}

/// Editor-side mutable mission; see the file docs.
class MissionDraft {
  MissionDraft({
    this.id,
    required this.type,
    required this.config,
    this.required = true,
  });

  /// Stored row id, or `null` for a mission added in this edit session.
  int? id;

  MissionType type;
  MissionConfig config;
  bool required;

  /// Creates a draft with the default config for [type].
  factory MissionDraft.withDefaults(MissionType type) {
    return MissionDraft(type: type, config: _defaultConfig(type));
  }

  /// Structural validation key, or `null` when the draft can be saved.
  /// `MissionType.none` is never a valid row: "no missions" is expressed
  /// by an empty list, not by a `none` row.
  String? validationMessageKey() {
    if (type == MissionType.none) {
      return 'msgMissionInvalid';
    }
    if (config.type != type) {
      return 'msgMissionInvalid';
    }
    return config.validationMessageKey();
  }

  MissionDraft copy() {
    return MissionDraft(
      id: id,
      type: type,
      config: config,
      required: required,
    );
  }

  static MissionConfig _defaultConfig(MissionType type) {
    switch (type) {
      case MissionType.none:
        // Inert placeholder; validation rejects `none` drafts before save.
        return const PhotoMissionConfig();
      case MissionType.typing:
        return const TypingMissionConfig('');
      case MissionType.photo:
        return const PhotoMissionConfig();
      case MissionType.qr:
        return const QrMissionConfig('');
      case MissionType.barcode:
        return const BarcodeMissionConfig('');
      case MissionType.shake:
        return const ShakeMissionConfig(10);
      case MissionType.math:
        return const MathMissionConfig(
          questionCount: 5,
          difficulty: MathDifficulty.easy,
        );
    }
  }
}

/// A validated executable mission handed to the engine.
class MissionEntry {
  const MissionEntry({
    required this.id,
    required this.alarmId,
    required this.type,
    required this.orderIndex,
    required this.config,
    required this.required,
  });

  final int id;
  final int alarmId;
  final MissionType type;
  final int orderIndex;
  final MissionConfig config;
  final bool required;

  /// Builds an entry from [row], or `null` when the row is not executable:
  /// `none` rows are inert and malformed/invalid configs are skipped (the
  /// caller counts them for the invalid-setup warning). Never throws.
  static MissionEntry? tryFromRow(Mission row) {
    final MissionType type = MissionType.fromDbValue(row.type);
    if (type == MissionType.none) {
      return null;
    }
    final MissionConfig? config = parseMissionConfig(type, row.configJson);
    if (config == null || config.validationMessageKey() != null) {
      return null;
    }
    return MissionEntry(
      id: row.id,
      alarmId: row.alarmId,
      type: type,
      orderIndex: row.orderIndex,
      config: config,
      required: row.required,
    );
  }
}
