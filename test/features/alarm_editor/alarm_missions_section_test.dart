import 'package:alarmx/core/database/database.dart';
import 'package:alarmx/core/database/daos/mission_dao.dart';
import 'package:alarmx/core/l10n/app_strings.dart';
import 'package:alarmx/core/models/models.dart';
import 'package:alarmx/features/missions/mission_config.dart';
import 'package:alarmx/features/missions/mission_service.dart';
import 'package:alarmx/features/missions/photo/photo_fingerprint.dart';
import 'package:alarmx/features/missions/photo/photo_mission.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/test_doubles.dart';

// Mission section tests: real in-memory stack, real MissionService. The
// form is pumped in a tall viewport so every row builds without
// scrolling; dialogs are driven by key so the tests work in any locale.

/// Scripted reference-capture source for enrollment tests.
class FakeReferenceCapture implements PhotoCaptureSource {
  FakeReferenceCapture(this.outcome);

  final PhotoCaptureOutcome outcome;

  @override
  Future<PhotoCaptureOutcome> capturePhoto() async => outcome;
}

/// Scripted fingerprint source for enrollment tests.
class FakeReferencePrints implements FingerprintSource {
  FakeReferencePrints(this.results);

  final List<int?> results;

  @override
  Future<int?> fingerprintOf(String path) async {
    if (results.isEmpty) {
      return null;
    }
    return results.removeAt(0);
  }
}

void main() {
  late TestStack stack;
  final AppStrings en = AppStrings.forCode('en');
  final AppStrings ar = AppStrings.forCode('ar');

  setUp(() {
    stack = TestStack();
  });

  // NOTE: the stack is intentionally not closed (see the note in
  // alarm_editor_screen_test.dart): closing here traps a pending
  // zero-duration Timer at the postTest check.

  Future<void> pumpTallEditor(
    WidgetTester tester, {
    String language = AppLanguage.english,
    int? alarmId,
    PhotoCaptureSource? photoCaptureSource,
    FingerprintSource? photoFingerprintSource,
  }) async {
    tester.view.physicalSize = const Size(800, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await pumpEditor(
      tester,
      stack,
      language: language,
      alarmId: alarmId,
      photoCaptureSource: photoCaptureSource,
      photoFingerprintSource: photoFingerprintSource,
    );
  }

  Future<List<MissionEntry>> entriesFor(int alarmId) async {
    final AlarmMissions loaded =
        await stack.missions.getMissionsForAlarm(alarmId);
    return loaded.entries;
  }

  Future<int> invalidFor(int alarmId) async {
    final AlarmMissions loaded =
        await stack.missions.getMissionsForAlarm(alarmId);
    return loaded.invalidCount;
  }

  Future<int> missionRowCount() async {
    final row = await stack.db
        .customSelect('SELECT COUNT(*) AS c FROM missions')
        .getSingle();
    return row.read<int>('c');
  }

  /// Adds one mission through the type picker + config dialog.
  Future<void> addMission(
    WidgetTester tester,
    MissionType type, {
    String? text,
  }) async {
    await tester.tap(find.byKey(const Key('mission_add_button')));
    await pumpSettle(tester);
    await tester.tap(find.byKey(Key('mission_type_option_${type.name}')));
    await pumpSettle(tester);
    if (text != null) {
      await tester.enterText(
        find.byKey(const Key('mission_config_text')),
        text,
      );
      await tester.pump();
    }
    await tester.tap(find.byKey(const Key('mission_config_save')));
    await pumpSettle(tester);
  }

  Future<void> saveAlarm(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('editor_save_button')));
    await pumpSettle(tester);
  }

  group('create mode', () {
    testWidgets('empty state shows the placeholder text and add button',
        (WidgetTester tester) async {
      await pumpTallEditor(tester);

      expect(find.text(en.missionTitle), findsOneWidget);
      expect(
        find.text('${en.missionNone} \u2014 ${en.missionCaption}'),
        findsOneWidget,
      );
      expect(find.byKey(const Key('mission_add_button')), findsOneWidget);
      expect(find.byKey(const Key('mission_row_0')), findsNothing);
      await finishWidgetTest(tester, stack);
    });

    testWidgets('type picker offers every mission type',
        (WidgetTester tester) async {
      await pumpTallEditor(tester);

      await tester.tap(find.byKey(const Key('mission_add_button')));
      await pumpSettle(tester);

      expect(find.text(en.missionPickType), findsOneWidget);
      for (final MissionType type in MissionType.values) {
        if (type == MissionType.none) {
          expect(
            find.byKey(Key('mission_type_option_${type.name}')),
            findsNothing,
          );
        } else {
          expect(
            find.byKey(Key('mission_type_option_${type.name}')),
            findsOneWidget,
          );
        }
      }
      await finishWidgetTest(tester, stack);
    });

    testWidgets('typing mission is configured and saved with the alarm',
        (WidgetTester tester) async {
      await pumpTallEditor(tester);

      await addMission(tester, MissionType.typing, text: 'wake up');
      expect(find.text('1. ${en.missionTyping}'), findsOneWidget);
      expect(find.textContaining('wake up'), findsOneWidget);

      await saveAlarm(tester);

      expect(find.byKey(const Key('editor_save_button')), findsNothing);
      final List<Alarm> alarms = await stack.repository.getAlarms();
      expect(alarms, hasLength(1));
      final List<MissionEntry> entries = await entriesFor(alarms.single.id);
      expect(entries, hasLength(1));
      expect(entries.single.type, MissionType.typing);
      expect(entries.single.orderIndex, 0);
      expect(entries.single.required, isTrue);
      expect(
        (entries.single.config as TypingMissionConfig).expectedText,
        'wake up',
      );
      await finishWidgetTest(tester, stack);
    });

    testWidgets('photo mission allows a blank label',
        (WidgetTester tester) async {
      await pumpTallEditor(
        tester,
        photoCaptureSource:
            FakeReferenceCapture(const PhotoCaptured('/ref.jpg')),
        photoFingerprintSource:
            FakeReferencePrints(<int?>[0x123456789ABCDEF0]),
      );

      await tester.tap(find.byKey(const Key('mission_add_button')));
      await pumpSettle(tester);
      await tester.tap(
        find.byKey(Key('mission_type_option_${MissionType.photo.name}')),
      );
      await pumpSettle(tester);
      await tester.tap(
        find.byKey(const Key('mission_config_capture_reference')),
      );
      await pumpSettle(tester);
      expect(find.text(en.photoReferenceDone), findsOneWidget);
      await tester.tap(find.byKey(const Key('mission_config_save')));
      await pumpSettle(tester);
      expect(find.text('1. ${en.missionPhoto}'), findsOneWidget);

      await saveAlarm(tester);

      final List<Alarm> alarms = await stack.repository.getAlarms();
      expect(alarms, hasLength(1));
      final List<MissionEntry> entries = await entriesFor(alarms.single.id);
      expect(entries, hasLength(1));
      expect(entries.single.type, MissionType.photo);
      final PhotoMissionConfig photo =
          entries.single.config as PhotoMissionConfig;
      expect(photo.label, '');
      expect(photo.fingerprint, 0x123456789ABCDEF0);
      await finishWidgetTest(tester, stack);
    });

    testWidgets('photo mission without a reference is rejected in the dialog',
        (WidgetTester tester) async {
      await pumpTallEditor(tester);

      await tester.tap(find.byKey(const Key('mission_add_button')));
      await pumpSettle(tester);
      await tester.tap(
        find.byKey(Key('mission_type_option_${MissionType.photo.name}')),
      );
      await pumpSettle(tester);
      await tester.tap(find.byKey(const Key('mission_config_save')));
      await pumpSettle(tester);

      expect(find.text(en.photoReferenceRequired), findsWidgets);
      expect(find.byKey(const Key('mission_config_save')), findsOneWidget);
      expect(find.byKey(const Key('mission_row_0')), findsNothing);
      await finishWidgetTest(tester, stack);
    });

    testWidgets('degenerate reference photo is rejected',
        (WidgetTester tester) async {
      await pumpTallEditor(
        tester,
        photoCaptureSource:
            FakeReferenceCapture(const PhotoCaptured('/blank.jpg')),
        photoFingerprintSource: FakeReferencePrints(<int?>[0]),
      );

      await tester.tap(find.byKey(const Key('mission_add_button')));
      await pumpSettle(tester);
      await tester.tap(
        find.byKey(Key('mission_type_option_${MissionType.photo.name}')),
      );
      await pumpSettle(tester);
      await tester.tap(
        find.byKey(const Key('mission_config_capture_reference')),
      );
      await pumpSettle(tester);

      expect(find.text(en.photoReferenceWeak), findsOneWidget);
      expect(find.text(en.photoReferenceDone), findsNothing);
      await finishWidgetTest(tester, stack);
    });

    testWidgets('memory mission is configured and saved with the alarm',
        (WidgetTester tester) async {
      await pumpTallEditor(tester);

      await tester.tap(find.byKey(const Key('mission_add_button')));
      await pumpSettle(tester);
      await tester.tap(
        find.byKey(Key('mission_type_option_${MissionType.memory.name}')),
      );
      await pumpSettle(tester);
      await tester.tap(
        find.byKey(const Key('mission_config_memory_difficulty')),
      );
      await pumpSettle(tester);
      await tester.tap(find.text(en.memoryHard));
      await pumpSettle(tester);
      await tester.tap(find.byKey(const Key('mission_config_save')));
      await pumpSettle(tester);
      expect(find.text('1. ${en.missionMemory}'), findsOneWidget);
      // The row subtitle appends the requirement flag, so match by
      // containment (same as the math-difficulty assertion below).
      expect(find.textContaining(en.memoryHard), findsOneWidget);

      await saveAlarm(tester);

      final List<Alarm> alarms = await stack.repository.getAlarms();
      final List<MissionEntry> entries = await entriesFor(alarms.single.id);
      expect(entries.single.type, MissionType.memory);
      expect(
        (entries.single.config as MemoryMissionConfig).difficulty,
        MemoryDifficulty.hard,
      );
      await finishWidgetTest(tester, stack);
    });

    testWidgets('sequence mission is configured and saved with the alarm',
        (WidgetTester tester) async {
      await pumpTallEditor(tester);

      await tester.tap(find.byKey(const Key('mission_add_button')));
      await pumpSettle(tester);
      await tester.tap(
        find.byKey(Key('mission_type_option_${MissionType.sequence.name}')),
      );
      await pumpSettle(tester);
      await tester.tap(
        find.byKey(const Key('mission_config_sequence_difficulty')),
      );
      await pumpSettle(tester);
      await tester.tap(find.text(en.sequenceMedium));
      await pumpSettle(tester);
      await tester.tap(find.byKey(const Key('mission_config_save')));
      await pumpSettle(tester);
      expect(find.text('1. ${en.missionSequence}'), findsOneWidget);

      await saveAlarm(tester);

      final List<Alarm> alarms = await stack.repository.getAlarms();
      final List<MissionEntry> entries = await entriesFor(alarms.single.id);
      expect(entries.single.type, MissionType.sequence);
      expect(
        (entries.single.config as SequenceMissionConfig).difficulty,
        SequenceDifficulty.medium,
      );
      await finishWidgetTest(tester, stack);
    });

    testWidgets('light mission is configured and saved with the alarm',
        (WidgetTester tester) async {
      await pumpTallEditor(tester);

      await tester.tap(find.byKey(const Key('mission_add_button')));
      await pumpSettle(tester);
      await tester.tap(
        find.byKey(Key('mission_type_option_${MissionType.light.name}')),
      );
      await pumpSettle(tester);
      await tester.tap(find.byKey(const Key('mission_config_light_mode')));
      await pumpSettle(tester);
      await tester.tap(find.text(en.lightModeGlow));
      await pumpSettle(tester);
      await tester.tap(find.byKey(const Key('mission_config_save')));
      await pumpSettle(tester);
      expect(find.text('1. ${en.missionLight}'), findsOneWidget);

      await saveAlarm(tester);

      final List<Alarm> alarms = await stack.repository.getAlarms();
      final List<MissionEntry> entries = await entriesFor(alarms.single.id);
      expect(entries.single.type, MissionType.light);
      expect(
        (entries.single.config as LightMissionConfig).mode,
        LightMode.glowDot,
      );
      await finishWidgetTest(tester, stack);
    });

    testWidgets('blank typing text is rejected inside the dialog',
        (WidgetTester tester) async {
      await pumpTallEditor(tester);

      await tester.tap(find.byKey(const Key('mission_add_button')));
      await pumpSettle(tester);
      await tester.tap(
        find.byKey(
          Key('mission_type_option_${MissionType.typing.name}'),
        ),
      );
      await pumpSettle(tester);
      await tester.tap(find.byKey(const Key('mission_config_save')));
      await pumpSettle(tester);

      // Invalid: inline error, dialog stays open, no row added.
      expect(find.text(en.missionFieldRequired), findsOneWidget);
      expect(find.byKey(const Key('mission_config_save')), findsOneWidget);
      expect(find.byKey(const Key('mission_row_0')), findsNothing);

      await tester.enterText(
        find.byKey(const Key('mission_config_text')),
        'done',
      );
      await tester.pump();
      await tester.tap(find.byKey(const Key('mission_config_save')));
      await pumpSettle(tester);

      expect(find.text('1. ${en.missionTyping}'), findsOneWidget);
      await finishWidgetTest(tester, stack);
    });

    testWidgets('required toggle flips and persists',
        (WidgetTester tester) async {
      await pumpTallEditor(tester);

      await addMission(tester, MissionType.shake);
      expect(find.textContaining(en.missionRequired), findsWidgets);
      await tester.tap(find.byKey(const Key('mission_required_0')));
      await pumpSettle(tester);
      expect(find.textContaining(en.missionOptional), findsOneWidget);

      await saveAlarm(tester);

      final List<Alarm> alarms = await stack.repository.getAlarms();
      final List<MissionEntry> entries = await entriesFor(alarms.single.id);
      expect(entries.single.required, isFalse);
      expect(
        (entries.single.config as ShakeMissionConfig).requiredCount,
        10,
      );
      await finishWidgetTest(tester, stack);
    });

    testWidgets('reorder changes the persisted execution order',
        (WidgetTester tester) async {
      await pumpTallEditor(tester);

      await addMission(tester, MissionType.typing, text: 'aaa');
      await addMission(tester, MissionType.shake);
      expect(find.text('1. ${en.missionTyping}'), findsOneWidget);
      expect(find.text('2. ${en.missionShake}'), findsOneWidget);

      await tester.tap(find.byKey(const Key('mission_down_0')));
      await pumpSettle(tester);
      expect(find.text('1. ${en.missionShake}'), findsOneWidget);
      expect(find.text('2. ${en.missionTyping}'), findsOneWidget);

      await saveAlarm(tester);

      final List<Alarm> alarms = await stack.repository.getAlarms();
      final List<MissionEntry> entries = await entriesFor(alarms.single.id);
      expect(entries.map((MissionEntry e) => e.type),
          <MissionType>[MissionType.shake, MissionType.typing]);
      expect(entries.map((MissionEntry e) => e.orderIndex), <int>[0, 1]);
      await finishWidgetTest(tester, stack);
    });

    testWidgets('delete asks for confirmation',
        (WidgetTester tester) async {
      await pumpTallEditor(tester);

      await addMission(tester, MissionType.typing, text: 'aaa');
      await tester.tap(find.byKey(const Key('mission_delete_0')));
      await pumpSettle(tester);
      expect(find.text(en.missionDeleteTitle), findsOneWidget);

      // Cancel keeps the row.
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text(en.cancel),
        ),
      );
      await pumpSettle(tester);
      expect(find.byKey(const Key('mission_row_0')), findsOneWidget);

      // Confirm removes it.
      await tester.tap(find.byKey(const Key('mission_delete_0')));
      await pumpSettle(tester);
      await tester.tap(find.byKey(const Key('mission_delete_confirm')));
      await pumpSettle(tester);
      expect(find.byKey(const Key('mission_row_0')), findsNothing);

      await saveAlarm(tester);
      expect(await missionRowCount(), 0);
      await finishWidgetTest(tester, stack);
    });

    testWidgets('qr and barcode values persist',
        (WidgetTester tester) async {
      await pumpTallEditor(tester);

      await addMission(tester, MissionType.qr, text: 'QR-1');
      await addMission(tester, MissionType.barcode, text: 'BAR-2');
      await saveAlarm(tester);

      final List<Alarm> alarms = await stack.repository.getAlarms();
      final List<MissionEntry> entries = await entriesFor(alarms.single.id);
      expect(entries, hasLength(2));
      expect(
        (entries[0].config as QrMissionConfig).expectedValue,
        'QR-1',
      );
      expect(
        (entries[1].config as BarcodeMissionConfig).expectedValue,
        'BAR-2',
      );
      await finishWidgetTest(tester, stack);
    });

    testWidgets('math difficulty and count persist',
        (WidgetTester tester) async {
      await pumpTallEditor(tester);

      await tester.tap(find.byKey(const Key('mission_add_button')));
      await pumpSettle(tester);
      await tester.tap(
        find.byKey(Key('mission_type_option_${MissionType.math.name}')),
      );
      await pumpSettle(tester);
      await tester.tap(find.byKey(const Key('mission_config_difficulty')));
      await pumpSettle(tester);
      await tester.tap(find.text(en.mathHard));
      await pumpSettle(tester);
      // The snooze card behind the dialog shows the same numerals, so
      // the chip tap is scoped to the dialog.
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text('10'),
        ),
      );
      await pumpSettle(tester);
      await tester.tap(find.byKey(const Key('mission_config_save')));
      await pumpSettle(tester);
      expect(find.textContaining(en.mathHard), findsOneWidget);

      await saveAlarm(tester);

      final List<Alarm> alarms = await stack.repository.getAlarms();
      final List<MissionEntry> entries = await entriesFor(alarms.single.id);
      expect(entries, hasLength(1));
      final MathMissionConfig config = entries.single.config as MathMissionConfig;
      expect(config.difficulty, MathDifficulty.hard);
      expect(config.questionCount, 10);
      await finishWidgetTest(tester, stack);
    });

    testWidgets('arabic labels render through the same flow',
        (WidgetTester tester) async {
      await pumpTallEditor(tester, language: AppLanguage.arabic);

      expect(find.text(ar.missionAdd), findsOneWidget);
      await addMission(tester, MissionType.typing, text: 'wake up');
      expect(find.text('1. ${ar.missionTyping}'), findsOneWidget);

      await saveAlarm(tester);

      final List<Alarm> alarms = await stack.repository.getAlarms();
      expect(alarms, hasLength(1));
      expect(
        await entriesFor(alarms.single.id),
        hasLength(1),
      );
      await finishWidgetTest(tester, stack);
    });
  });

  group('edit mode', () {
    testWidgets('stored missions load and save back together',
        (WidgetTester tester) async {
      final int alarmId = await stack.insertAlarm(label: 'Gym');
      await stack.missions.saveMissionsForAlarm(alarmId, <MissionDraft>[
        MissionDraft(
          type: MissionType.typing,
          config: const TypingMissionConfig('old'),
        ),
        MissionDraft(
          type: MissionType.shake,
          config: const ShakeMissionConfig(10),
          required: false,
        ),
      ]);

      await pumpTallEditor(tester, alarmId: alarmId);

      expect(find.text('1. ${en.missionTyping}'), findsOneWidget);
      expect(find.text('2. ${en.missionShake}'), findsOneWidget);
      expect(find.textContaining('old'), findsOneWidget);

      await tester.tap(find.byKey(const Key('mission_edit_0')));
      await pumpSettle(tester);
      await tester.enterText(
        find.byKey(const Key('mission_config_text')),
        'new',
      );
      await tester.pump();
      await tester.tap(find.byKey(const Key('mission_config_save')));
      await pumpSettle(tester);
      expect(find.textContaining('new'), findsOneWidget);

      await saveAlarm(tester);

      expect(find.byKey(const Key('editor_save_button')), findsNothing);
      final List<MissionEntry> entries = await entriesFor(alarmId);
      expect(entries, hasLength(2));
      expect(
        (entries[0].config as TypingMissionConfig).expectedText,
        'new',
      );
      expect(entries[0].required, isTrue);
      expect(entries[1].type, MissionType.shake);
      expect(entries[1].required, isFalse);
      await finishWidgetTest(tester, stack);
    });

    testWidgets('malformed and none rows are dropped with a warning',
        (WidgetTester tester) async {
      final int alarmId = await stack.insertAlarm();
      final MissionDao dao = stack.db.missionDao;
      await dao.insertMission(
        MissionsCompanion.insert(
          alarmId: alarmId,
          type: MissionType.none.dbValue,
          orderIndex: const Value<int>(0),
          configJson: const Value<String>('{}'),
          required: const Value<bool>(true),
        ),
      );
      await dao.insertMission(
        MissionsCompanion.insert(
          alarmId: alarmId,
          type: MissionType.typing.dbValue,
          orderIndex: const Value<int>(1),
          configJson: const Value<String>('not-json'),
          required: const Value<bool>(true),
        ),
      );
      await dao.insertMission(
        MissionsCompanion.insert(
          alarmId: alarmId,
          type: MissionType.shake.dbValue,
          orderIndex: const Value<int>(2),
          configJson: const Value<String>('{"count": 10}'),
          required: const Value<bool>(true),
        ),
      );
      expect(await invalidFor(alarmId), 1);

      await pumpTallEditor(tester, alarmId: alarmId);

      // Only the executable row renders, with a visible warning.
      expect(find.text('1. ${en.missionShake}'), findsOneWidget);
      expect(find.text(en.msgMissionInvalid), findsOneWidget);

      await saveAlarm(tester);

      // Saving rewrites a clean list; the garbage rows are gone.
      expect(await missionRowCount(), 1);
      final List<MissionEntry> entries = await entriesFor(alarmId);
      expect(entries.single.type, MissionType.shake);
      await finishWidgetTest(tester, stack);
    });
  });
}
