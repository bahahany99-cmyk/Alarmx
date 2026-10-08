// Integration tests for the ringing mission screen: mission loading,
// ordered execution across mission types, skip/required rules, invalid
// setup warnings, stop-on-completion, stop failure/retry, and app-shell
// ring-launch routing. Real in-memory Drift stack; fake bridge + mission
// execution overrides (no cameras, sensors, or channels).

import 'dart:async' show StreamController;
import 'dart:math' show Random;

import 'package:alarmx/core/database/database.dart';
import 'package:alarmx/core/l10n/app_strings.dart';
import 'package:alarmx/core/models/models.dart';
import 'package:alarmx/core/repositories/mission_repository.dart';
import 'package:alarmx/features/missions/code_scan/code_scan_mission.dart';
import 'package:alarmx/features/missions/code_scan/code_scan_mission_widget.dart';
import 'package:alarmx/features/missions/math/math_mission.dart';
import 'package:alarmx/features/missions/mission_config.dart';
import 'package:alarmx/features/missions/mission_service.dart';
import 'package:alarmx/features/missions/permissions/camera_permission.dart';
import 'package:alarmx/features/missions/photo/photo_mission.dart';
import 'package:alarmx/features/missions/shake/shake_mission.dart';
import 'package:alarmx/features/ringing_alarm/ringing_alarm_bridge.dart';
import 'package:alarmx/features/ringing_alarm/ringing_launch.dart';
import 'package:alarmx/features/ringing_alarm/ringing_mission_screen.dart';
import 'package:alarmx/main.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/test_doubles.dart';

class FakeRingingBridge implements RingingAlarmBridge {
  FakeRingingBridge({this.launch});

  RingingLaunch? launch;
  final List<int> stops = <int>[];
  final List<Object> stopErrors = <Object>[];

  @override
  Future<RingingLaunch?> consumeRingingLaunch() async => launch;

  @override
  Future<void> stopRingingAlarm(int alarmId) async {
    if (stopErrors.isNotEmpty) {
      throw stopErrors.removeAt(0);
    }
    stops.add(alarmId);
  }
}

class GrantedPermissionGate implements CameraPermissionGate {
  @override
  Future<CameraPermissionOutcome> requestCamera() async =>
      CameraPermissionOutcome.granted;

  @override
  Future<CameraPermissionOutcome> checkCameraStatus() async =>
      CameraPermissionOutcome.granted;

  @override
  Future<void> openSettings() async {}
}

ScannerViewBuilder stubScanner(String expected) {
  return (
    BuildContext context,
    CodeScanMissionController controller,
    int nonce,
  ) {
    return TextButton(
      key: const Key('stub_scan_button'),
      onPressed: () => controller.onCodeDetected(expected),
      child: const Text('scan'),
    );
  };
}

class FakePhotoSource implements PhotoCaptureSource {
  FakePhotoSource(this.outcome);

  PhotoCaptureOutcome outcome;

  @override
  Future<PhotoCaptureOutcome> capturePhoto() async => outcome;
}

class FakeShakeSource implements ShakeSensorSource {
  final StreamController<AccelSample> events =
      StreamController<AccelSample>.broadcast();

  @override
  Stream<AccelSample> get samples => events.stream;

  Future<void> close() => events.close();
}

class ThrowingLoadRepository implements MissionRepository {
  ThrowingLoadRepository(this._inner);

  final MissionRepository _inner;

  @override
  Future<List<Mission>> getMissionsForAlarm(int alarmId) {
    throw StateError('boom');
  }

  @override
  Future<Mission?> getMissionById(int id) => _inner.getMissionById(id);

  @override
  Future<int> createMission(MissionsCompanion entry) =>
      _inner.createMission(entry);

  @override
  Future<bool> updateMission(Mission entry) => _inner.updateMission(entry);

  @override
  Future<bool> deleteMission(int id) => _inner.deleteMission(id);

  @override
  Future<int> deleteMissionsForAlarm(int alarmId) =>
      _inner.deleteMissionsForAlarm(alarmId);

  @override
  Future<void> replaceMissionsForAlarm(
    int alarmId,
    List<MissionsCompanion> entries,
  ) =>
      _inner.replaceMissionsForAlarm(alarmId, entries);
}

MissionDraft typing(String text, {bool required = true}) {
  return MissionDraft(
    type: MissionType.typing,
    config: TypingMissionConfig(text),
    required: required,
  );
}

Future<void> pumpRinging(
  WidgetTester tester,
  TestStack stack, {
  required int alarmId,
  required FakeRingingBridge bridge,
  required VoidCallback onFinished,
  MissionTestOverrides overrides = const MissionTestOverrides(),
  MissionService? missionService,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale(AppLanguage.english),
      supportedLocales: testLocales,
      localizationsDelegates: testDelegates,
      home: RingingMissionScreen(
        launch: RingingLaunch(alarmId: alarmId, label: 'Morning'),
        alarms: stack.repository,
        missionService: missionService ?? stack.missions,
        history: stack.history,
        coordinator: stack.coordinator,
        pinService: stack.pinService,
        bridge: bridge,
        onFinished: onFinished,
        overrides: overrides,
      ),
    ),
  );
  await pumpSettle(tester);
}

Future<void> solveTyping(
  WidgetTester tester,
  String text,
) async {
  await tester.enterText(find.byKey(const Key('typing_answer_field')), text);
  await tester.tap(find.byKey(const Key('typing_check_button')));
  await pumpSettle(tester);
}

void main() {
  final AppStrings en = AppStrings.forCode(AppLanguage.english);
  late TestStack stack;

  setUp(() {
    stack = TestStack();
  });

  testWidgets('no missions shows stop and stops', (WidgetTester tester) async {
    final int alarmId = await stack.insertAlarm();
    final FakeRingingBridge bridge = FakeRingingBridge();
    int finished = 0;
    await pumpRinging(
      tester,
      stack,
      alarmId: alarmId,
      bridge: bridge,
      onFinished: () {
        finished++;
      },
    );
    expect(find.text(en.ringingNoMissions), findsOneWidget);
    expect(bridge.stops, isEmpty);
    await tester.tap(find.byKey(const Key('ringing_stop_button')));
    await pumpSettle(tester);
    expect(bridge.stops, <int>[alarmId]);
    expect(finished, 1);
    await finishWidgetTest(tester, stack);
  });

  testWidgets('load failure stays stoppable', (WidgetTester tester) async {
    final int alarmId = await stack.insertAlarm();
    final FakeRingingBridge bridge = FakeRingingBridge();
    int finished = 0;
    await pumpRinging(
      tester,
      stack,
      alarmId: alarmId,
      bridge: bridge,
      onFinished: () {
        finished++;
      },
      missionService: MissionService(
        ThrowingLoadRepository(
          DriftMissionRepository(stack.db.missionDao),
        ),
      ),
    );
    expect(find.text(en.ringingLoadFailed), findsOneWidget);
    await tester.tap(find.byKey(const Key('ringing_stop_button')));
    await pumpSettle(tester);
    expect(bridge.stops, <int>[alarmId]);
    expect(finished, 1);
    await finishWidgetTest(tester, stack);
  });

  testWidgets('one typing mission solves then stops',
      (WidgetTester tester) async {
    final int alarmId = await stack.insertAlarm();
    await stack.missions.saveMissionsForAlarm(alarmId, <MissionDraft>[
      typing('wake up'),
    ]);
    final FakeRingingBridge bridge = FakeRingingBridge();
    int finished = 0;
    await pumpRinging(
      tester,
      stack,
      alarmId: alarmId,
      bridge: bridge,
      onFinished: () {
        finished++;
      },
    );
    expect(
      find.text('${en.missionProgress} 1 / 1'),
      findsOneWidget,
    );
    expect(bridge.stops, isEmpty);
    await solveTyping(tester, 'wake up');
    expect(bridge.stops, <int>[alarmId]);
    expect(finished, 1);
    await finishWidgetTest(tester, stack);
  });

  testWidgets('multiple missions execute in order without premature stop',
      (WidgetTester tester) async {
    final int alarmId = await stack.insertAlarm();
    await stack.missions.saveMissionsForAlarm(alarmId, <MissionDraft>[
      typing('first'),
      typing('second'),
    ]);
    final FakeRingingBridge bridge = FakeRingingBridge();
    int finished = 0;
    await pumpRinging(
      tester,
      stack,
      alarmId: alarmId,
      bridge: bridge,
      onFinished: () {
        finished++;
      },
    );
    expect(find.text('${en.missionProgress} 1 / 2'), findsOneWidget);
    await solveTyping(tester, 'first');
    expect(find.text('${en.missionProgress} 2 / 2'), findsOneWidget);
    expect(bridge.stops, isEmpty);
    expect(finished, 0);
    await solveTyping(tester, 'second');
    expect(bridge.stops, <int>[alarmId]);
    expect(finished, 1);
    await finishWidgetTest(tester, stack);
  });

  testWidgets('optional mission can be skipped, required cannot',
      (WidgetTester tester) async {
    final int alarmId = await stack.insertAlarm();
    await stack.missions.saveMissionsForAlarm(alarmId, <MissionDraft>[
      typing('must'),
      typing('maybe', required: false),
    ]);
    final FakeRingingBridge bridge = FakeRingingBridge();
    int finished = 0;
    await pumpRinging(
      tester,
      stack,
      alarmId: alarmId,
      bridge: bridge,
      onFinished: () {
        finished++;
      },
    );
    expect(find.byKey(const Key('ringing_skip_button')), findsNothing);
    await solveTyping(tester, 'must');
    expect(find.byKey(const Key('ringing_skip_button')), findsOneWidget);
    await tester.tap(find.byKey(const Key('ringing_skip_button')));
    await pumpSettle(tester);
    expect(bridge.stops, <int>[alarmId]);
    expect(finished, 1);
    await finishWidgetTest(tester, stack);
  });

  testWidgets('invalid rows warn but do not block completion',
      (WidgetTester tester) async {
    final int alarmId = await stack.insertAlarm();
    await stack.missions.saveMissionsForAlarm(alarmId, <MissionDraft>[
      typing('good'),
    ]);
    await stack.db.missionDao.insertMission(
      MissionsCompanion.insert(
        alarmId: alarmId,
        type: MissionType.typing.dbValue,
        orderIndex: const Value(1),
        configJson: const Value('junk'),
      ),
    );
    final FakeRingingBridge bridge = FakeRingingBridge();
    int finished = 0;
    await pumpRinging(
      tester,
      stack,
      alarmId: alarmId,
      bridge: bridge,
      onFinished: () {
        finished++;
      },
    );
    expect(find.text(en.ringingSkippedInvalid), findsOneWidget);
    await solveTyping(tester, 'good');
    expect(bridge.stops, <int>[alarmId]);
    expect(finished, 1);
    await finishWidgetTest(tester, stack);
  });

  testWidgets('stop failure shows retry and recovers',
      (WidgetTester tester) async {
    final int alarmId = await stack.insertAlarm();
    await stack.missions.saveMissionsForAlarm(alarmId, <MissionDraft>[
      typing('wake up'),
    ]);
    final FakeRingingBridge bridge = FakeRingingBridge()
      ..stopErrors.add(StateError('native down'));
    int finished = 0;
    await pumpRinging(
      tester,
      stack,
      alarmId: alarmId,
      bridge: bridge,
      onFinished: () {
        finished++;
      },
    );
    await solveTyping(tester, 'wake up');
    expect(find.text(en.ringingStopFailed), findsOneWidget);
    expect(bridge.stops, isEmpty);
    expect(finished, 0);
    await tester.tap(find.byKey(const Key('ringing_retry_button')));
    await pumpSettle(tester);
    expect(bridge.stops, <int>[alarmId]);
    expect(finished, 1);
    await finishWidgetTest(tester, stack);
  });

  testWidgets('qr mission scans through the stubbed view',
      (WidgetTester tester) async {
    final int alarmId = await stack.insertAlarm();
    await stack.missions.saveMissionsForAlarm(alarmId, <MissionDraft>[
      MissionDraft(
        type: MissionType.qr,
        config: const QrMissionConfig('QR-1'),
      ),
    ]);
    final FakeRingingBridge bridge = FakeRingingBridge();
    int finished = 0;
    await pumpRinging(
      tester,
      stack,
      alarmId: alarmId,
      bridge: bridge,
      onFinished: () {
        finished++;
      },
      overrides: MissionTestOverrides(
        permissionGate: GrantedPermissionGate(),
        scannerBuilder: stubScanner('QR-1'),
      ),
    );
    expect(find.text(en.qrInstruction), findsOneWidget);
    await tester.tap(find.byKey(const Key('stub_scan_button')));
    await pumpSettle(tester);
    expect(bridge.stops, <int>[alarmId]);
    expect(finished, 1);
    await finishWidgetTest(tester, stack);
  });

  testWidgets('shake mission completes from the fake sensor',
      (WidgetTester tester) async {
    final int alarmId = await stack.insertAlarm();
    await stack.missions.saveMissionsForAlarm(alarmId, <MissionDraft>[
      MissionDraft(
        type: MissionType.shake,
        config: const ShakeMissionConfig(1),
      ),
    ]);
    final FakeRingingBridge bridge = FakeRingingBridge();
    final FakeShakeSource source = FakeShakeSource();
    addTearDown(source.close);
    int finished = 0;
    await pumpRinging(
      tester,
      stack,
      alarmId: alarmId,
      bridge: bridge,
      onFinished: () {
        finished++;
      },
      overrides: MissionTestOverrides(shakeSource: source),
    );
    expect(find.text('0 / 1'), findsOneWidget);
    source.events.add(const AccelSample(20, 0, 0));
    await pumpSettle(tester);
    expect(bridge.stops, <int>[alarmId]);
    expect(finished, 1);
    await finishWidgetTest(tester, stack);
  });

  testWidgets('photo mission captures through the fake source',
      (WidgetTester tester) async {
    final int alarmId = await stack.insertAlarm();
    await stack.missions.saveMissionsForAlarm(alarmId, <MissionDraft>[
      MissionDraft(
        type: MissionType.photo,
        config: const PhotoMissionConfig('sink'),
      ),
    ]);
    final FakeRingingBridge bridge = FakeRingingBridge();
    int finished = 0;
    await pumpRinging(
      tester,
      stack,
      alarmId: alarmId,
      bridge: bridge,
      onFinished: () {
        finished++;
      },
      overrides: MissionTestOverrides(
        photoSource: FakePhotoSource(const PhotoCaptured('/shot.jpg')),
      ),
    );
    await tester.tap(find.byKey(const Key('photo_take_button')));
    await pumpSettle(tester);
    expect(bridge.stops, <int>[alarmId]);
    expect(finished, 1);
    await finishWidgetTest(tester, stack);
  });

  testWidgets('math mission solves with a seeded random',
      (WidgetTester tester) async {
    const MathMissionConfig config = MathMissionConfig(
      questionCount: 2,
      difficulty: MathDifficulty.easy,
    );
    final int alarmId = await stack.insertAlarm();
    await stack.missions.saveMissionsForAlarm(alarmId, <MissionDraft>[
      MissionDraft(type: MissionType.math, config: config),
    ]);
    final FakeRingingBridge bridge = FakeRingingBridge();
    int finished = 0;
    const int seed = 21;
    await pumpRinging(
      tester,
      stack,
      alarmId: alarmId,
      bridge: bridge,
      onFinished: () {
        finished++;
      },
      overrides: MissionTestOverrides(mathRandom: Random(seed)),
    );
    final List<MathQuestion> expected =
        MathQuestionGenerator(Random(seed)).generate(config);
    for (final MathQuestion question in expected) {
      await tester.enterText(
        find.byKey(const Key('math_answer_field')),
        '${question.answer}',
      );
      await tester.tap(find.byKey(const Key('math_solve_button')));
      await pumpSettle(tester);
    }
    expect(bridge.stops, <int>[alarmId]);
    expect(finished, 1);
    await finishWidgetTest(tester, stack);
  });

  testWidgets('app shell routes ring launches to missions then home',
      (WidgetTester tester) async {
    final int alarmId = await stack.insertAlarm();
    await stack.setLanguage(AppLanguage.english);
    final FakeRingingBridge bridge = FakeRingingBridge(
      launch: RingingLaunch(alarmId: alarmId, label: 'Morning'),
    );
    await tester.pumpWidget(
      AlarmxApp(
        repository: stack.repository,
        coordinator: stack.coordinator,
        settings: stack.settings,
        missionService: stack.missions,
        history: stack.history,
        ringingBridge: bridge,
      ),
    );
    await pumpSettle(tester);
    expect(find.text(en.ringingNoMissions), findsOneWidget);
    await tester.tap(find.byKey(const Key('ringing_stop_button')));
    await pumpSettle(tester);
    expect(bridge.stops, <int>[alarmId]);
    expect(find.byKey(const Key('add_alarm_fab')), findsOneWidget);
    await finishWidgetTest(tester, stack);
  });
}
