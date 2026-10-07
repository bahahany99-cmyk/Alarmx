// Tests for the mission domain model: config JSON round-trips,
// malformed-config tolerance, validation boundaries, drafts, entries.

import 'package:alarmx/core/database/database.dart';
import 'package:alarmx/core/models/models.dart';
import 'package:alarmx/features/missions/mission_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('parseMissionConfig', () {
    test('none has no config', () {
      expect(parseMissionConfig(MissionType.none, null), isNull);
      expect(parseMissionConfig(MissionType.none, '{"a":1}'), isNull);
    });

    test('typing round-trip', () {
      const TypingMissionConfig config = TypingMissionConfig('wake up');
      final MissionConfig? parsed = parseMissionConfig(
        MissionType.typing,
        encodeMissionConfig(config),
      );
      expect(parsed, isA<TypingMissionConfig>());
      expect((parsed! as TypingMissionConfig).expectedText, 'wake up');
    });

    test('photo round-trip, missing config tolerated', () {
      const PhotoMissionConfig config = PhotoMissionConfig('sink');
      final MissionConfig? parsed = parseMissionConfig(
        MissionType.photo,
        encodeMissionConfig(config),
      );
      expect((parsed! as PhotoMissionConfig).label, 'sink');
      final MissionConfig? missing =
          parseMissionConfig(MissionType.photo, null);
      expect(missing, isA<PhotoMissionConfig>());
      expect((missing! as PhotoMissionConfig).label, isEmpty);
    });

    test('qr and barcode round-trips', () {
      const QrMissionConfig qr = QrMissionConfig('ALARMX-QR-1');
      final MissionConfig? parsedQr =
          parseMissionConfig(MissionType.qr, encodeMissionConfig(qr));
      expect((parsedQr! as QrMissionConfig).expectedValue, 'ALARMX-QR-1');
      const BarcodeMissionConfig bc = BarcodeMissionConfig('5901234123457');
      final MissionConfig? parsedBc = parseMissionConfig(
        MissionType.barcode,
        encodeMissionConfig(bc),
      );
      expect(
        (parsedBc! as BarcodeMissionConfig).expectedValue,
        '5901234123457',
      );
    });

    test('shake and math round-trips', () {
      const ShakeMissionConfig shake = ShakeMissionConfig(15);
      final MissionConfig? parsedShake = parseMissionConfig(
        MissionType.shake,
        encodeMissionConfig(shake),
      );
      expect((parsedShake! as ShakeMissionConfig).requiredCount, 15);
      const MathMissionConfig math = MathMissionConfig(
        questionCount: 10,
        difficulty: MathDifficulty.hard,
      );
      final MissionConfig? parsedMath =
          parseMissionConfig(MissionType.math, encodeMissionConfig(math));
      final MathMissionConfig mathParsed = parsedMath! as MathMissionConfig;
      expect(mathParsed.questionCount, 10);
      expect(mathParsed.difficulty, MathDifficulty.hard);
    });

    test('unknown fields are ignored', () {
      final MissionConfig? parsed = parseMissionConfig(
        MissionType.typing,
        '{"text": "ok", "future": {"nested": [1, 2]}, "v": 9}',
      );
      expect((parsed! as TypingMissionConfig).expectedText, 'ok');
    });

    test('malformed JSON never throws', () {
      const List<String?> bad = <String?>[
        null,
        '',
        '   ',
        'not json',
        '42',
        '"str"',
        '[1,2]',
        '{"text": 42}',
        '{"text": null}',
        '{"value": ["x"]}',
        '{"count": "10"}',
      ];
      // Count-bearing objects are *valid* shake configs (unknown fields are
      // ignored), so the math difficulty shapes are asserted per-type.
      expect(
        parseMissionConfig(MissionType.shake, '{"count": 5}'),
        isA<ShakeMissionConfig>(),
      );
      expect(
        parseMissionConfig(
          MissionType.shake,
          '{"count": 5, "difficulty": "insane"}',
        ),
        isA<ShakeMissionConfig>(),
      );
      expect(
        parseMissionConfig(MissionType.shake, '{"count": "10"}'),
        isNull,
      );
      for (final String json in <String>[
        '{"count": 5}',
        '{"count": 5, "difficulty": "insane"}',
        '{"count": 5, "difficulty": null}',
        '{"count": 5, "difficulty": 42}',
      ]) {
        expect(
          parseMissionConfig(MissionType.math, json),
          isNull,
          reason: json,
        );
      }
      for (final String? json in bad) {
        for (final MissionType type in MissionType.values) {
          if (type == MissionType.none) {
            continue;
          }
          expect(
            parseMissionConfig(type, json),
            anyOf(isNull, isA<PhotoMissionConfig>()),
            reason: 'type=$type json=$json',
          );
        }
      }
      // Photo tolerates only missing/empty/absent-label configs ...
      expect(parseMissionConfig(MissionType.photo, 'not json'), isNull);
      expect(parseMissionConfig(MissionType.photo, '42'), isNull);
      expect(parseMissionConfig(MissionType.photo, '{"label": 7}'), isNull);
      // ... and accepts an explicit empty label.
      expect(
        parseMissionConfig(MissionType.photo, '{"label": ""}'),
        isA<PhotoMissionConfig>(),
      );
      expect(
        parseMissionConfig(MissionType.photo, '{}'),
        isA<PhotoMissionConfig>(),
      );
    });
  });

  group('config validation', () {
    test('typing requires non-empty text within length', () {
      expect(
        const TypingMissionConfig('').validationMessageKey(),
        'missionFieldRequired',
      );
      expect(
        const TypingMissionConfig('   ').validationMessageKey(),
        'missionFieldRequired',
      );
      expect(
        TypingMissionConfig('x' * 121).validationMessageKey(),
        'missionFieldRequired',
      );
      expect(
        const TypingMissionConfig('ok').validationMessageKey(),
        isNull,
      );
    });

    test('qr/barcode require non-empty values within length', () {
      expect(
        const QrMissionConfig('').validationMessageKey(),
        'missionFieldRequired',
      );
      expect(
        QrMissionConfig('x' * 513).validationMessageKey(),
        'missionFieldRequired',
      );
      expect(
        const BarcodeMissionConfig('  ').validationMessageKey(),
        'missionFieldRequired',
      );
      expect(
        BarcodeMissionConfig('x' * 129).validationMessageKey(),
        'missionFieldRequired',
      );
      expect(
        const QrMissionConfig('v').validationMessageKey(),
        isNull,
      );
      expect(
        const BarcodeMissionConfig('v').validationMessageKey(),
        isNull,
      );
    });

    test('shake count range', () {
      expect(
        const ShakeMissionConfig(0).validationMessageKey(),
        'missionFieldRequired',
      );
      expect(
        const ShakeMissionConfig(51).validationMessageKey(),
        'missionFieldRequired',
      );
      expect(
        const ShakeMissionConfig(1).validationMessageKey(),
        isNull,
      );
      expect(
        const ShakeMissionConfig(50).validationMessageKey(),
        isNull,
      );
    });

    test('math count range', () {
      expect(
        const MathMissionConfig(
          questionCount: 0,
          difficulty: MathDifficulty.easy,
        ).validationMessageKey(),
        'missionFieldRequired',
      );
      expect(
        const MathMissionConfig(
          questionCount: 21,
          difficulty: MathDifficulty.easy,
        ).validationMessageKey(),
        'missionFieldRequired',
      );
      expect(
        const MathMissionConfig(
          questionCount: 3,
          difficulty: MathDifficulty.medium,
        ).validationMessageKey(),
        isNull,
      );
    });

    test('photo label is optional but length-capped', () {
      expect(const PhotoMissionConfig().validationMessageKey(), isNull);
      expect(
        PhotoMissionConfig('x' * 121).validationMessageKey(),
        'missionFieldRequired',
      );
    });

    test('MathDifficulty decoding', () {
      expect(MathDifficulty.fromDbValue('easy'), MathDifficulty.easy);
      expect(MathDifficulty.fromDbValue('medium'), MathDifficulty.medium);
      expect(MathDifficulty.fromDbValue('hard'), MathDifficulty.hard);
      expect(MathDifficulty.fromDbValue('insane'), isNull);
      expect(MathDifficulty.fromDbValue(null), isNull);
    });
  });

  group('MissionDraft', () {
    test('defaults per type', () {
      expect(
        MissionDraft.withDefaults(MissionType.typing).config,
        isA<TypingMissionConfig>(),
      );
      expect(
        MissionDraft.withDefaults(MissionType.photo).config,
        isA<PhotoMissionConfig>(),
      );
      expect(
        MissionDraft.withDefaults(MissionType.qr).config,
        isA<QrMissionConfig>(),
      );
      expect(
        MissionDraft.withDefaults(MissionType.barcode).config,
        isA<BarcodeMissionConfig>(),
      );
      final MissionDraft shake =
          MissionDraft.withDefaults(MissionType.shake);
      final int shakeCount =
          (shake.config as ShakeMissionConfig).requiredCount;
      expect(shakeCount >= kShakeMinCount && shakeCount <= kShakeMaxCount,
          isTrue);
      final MissionDraft math = MissionDraft.withDefaults(MissionType.math);
      expect(math.config.validationMessageKey(), isNull);
      expect(
        MissionDraft.withDefaults(MissionType.typing).required,
        isTrue,
      );
    });

    test('none drafts and config/type mismatches are invalid', () {
      expect(
        MissionDraft.withDefaults(MissionType.none).validationMessageKey(),
        'msgMissionInvalid',
      );
      final MissionDraft mismatch = MissionDraft(
        type: MissionType.qr,
        config: const TypingMissionConfig('x'),
      );
      expect(mismatch.validationMessageKey(), 'msgMissionInvalid');
      final MissionDraft bad = MissionDraft(
        type: MissionType.typing,
        config: const TypingMissionConfig(''),
      );
      expect(bad.validationMessageKey(), 'missionFieldRequired');
      final MissionDraft good = MissionDraft(
        type: MissionType.typing,
        config: const TypingMissionConfig('x'),
      );
      expect(good.validationMessageKey(), isNull);
    });
  });

  group('MissionEntry.tryFromRow', () {
    Mission rowOf(String type, String? configJson) {
      return Mission(
        id: 7,
        alarmId: 3,
        type: type,
        orderIndex: 2,
        configJson: configJson,
        required: false,
      );
    }

    test('valid rows become entries', () {
      final MissionEntry? entry = MissionEntry.tryFromRow(
        rowOf('typing', '{"text": "hi"}'),
      );
      expect(entry, isNotNull);
      expect(entry!.id, 7);
      expect(entry.alarmId, 3);
      expect(entry.type, MissionType.typing);
      expect(entry.orderIndex, 2);
      expect(entry.required, isFalse);
      expect((entry.config as TypingMissionConfig).expectedText, 'hi');
    });

    test('none, unknown, malformed and invalid rows are dropped', () {
      expect(MissionEntry.tryFromRow(rowOf('none', null)), isNull);
      expect(
        MissionEntry.tryFromRow(rowOf('none', '{"text": "x"}')),
        isNull,
      );
      // Unknown type strings fall back to `none` (inert).
      expect(MissionEntry.tryFromRow(rowOf('future', null)), isNull);
      expect(MissionEntry.tryFromRow(rowOf('typing', null)), isNull);
      expect(MissionEntry.tryFromRow(rowOf('typing', 'junk')), isNull);
      // Parses, but violates validation (empty expected text).
      expect(MissionEntry.tryFromRow(rowOf('typing', '{"text": ""}')), isNull);
      // Config/type mismatch: a typing config under a qr row.
      expect(MissionEntry.tryFromRow(rowOf('qr', '{"text": "x"}')), isNull);
    });
  });
}
