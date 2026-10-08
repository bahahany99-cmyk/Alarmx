import 'package:alarmx/core/models/models.dart';
import 'package:alarmx/core/permissions/capability_state.dart';
import 'package:alarmx/core/permissions/permission_bridge.dart';
import 'package:alarmx/features/missions/mission_config.dart';
import 'package:alarmx/features/missions/permissions/camera_permission.dart';
import 'package:alarmx/features/permission_center/reliability_calculator.dart';
import 'package:alarmx/features/permission_center/reliability_reader.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/test_doubles.dart';

// Reader assembly tests: real in-memory alarms + missions, scripted
// bridge + camera gate. No platform channels.

void main() {
  late TestStack stack;

  setUp(() {
    stack = TestStack();
  });

  tearDown(() async {
    await stack.close();
  });

  Future<ReliabilityData> read({
    PermissionSystemBridge? bridge,
    CameraPermissionGate? cameraGate,
  }) {
    return readReliability(
      bridge: bridge ?? FakePermissionSystemBridge(),
      cameraGate: cameraGate ?? FakeCameraStatusGate(),
      alarms: stack.repository,
      missions: stack.missions,
    );
  }

  test('granted snapshot with an enabled alarm is reliable', () async {
    await stack.insertAlarm(label: 'Work');

    final ReliabilityData data = await read();

    expect(data.report.overall, ReliabilityOverall.reliable);
    expect(data.enabledCount, 1);
    expect(data.cameraRelevant, isFalse);
    expect(data.snapshot.notifications, CapabilityState.granted);
    expect(data.snapshot.exactAlarm, CapabilityState.granted);
  });

  test('camera missions mark camera relevant', () async {
    final int alarmId = await stack.insertAlarm(label: 'QR alarm');
    await stack.missions.saveMissionsForAlarm(
      alarmId,
      <MissionDraft>[
        MissionDraft(
          type: MissionType.qr,
          config: const QrMissionConfig('CODE-1'),
        ),
      ],
    );

    final ReliabilityData data = await read();

    expect(data.cameraRelevant, isTrue);
    expect(
      data.report.levels[ReliabilityItemId.camera],
      ReliabilityLevel.ready,
    );
  });

  test('non-camera missions stay irrelevant', () async {
    final int alarmId = await stack.insertAlarm(label: 'Math alarm');
    await stack.missions.saveMissionsForAlarm(
      alarmId,
      <MissionDraft>[
        MissionDraft(
          type: MissionType.math,
          config: const MathMissionConfig(
            difficulty: MathDifficulty.easy,
            questionCount: 1,
          ),
        ),
      ],
    );

    final ReliabilityData data = await read();

    expect(data.cameraRelevant, isFalse);
  });

  test('permanently-denied camera maps to restricted', () async {
    await stack.insertAlarm(label: 'Work');

    final ReliabilityData data = await read(
      cameraGate: FakeCameraStatusGate(CameraPermissionOutcome.permanentlyDenied),
    );

    expect(data.snapshot.camera, CapabilityState.restricted);
  });

  test('denied camera maps to denied', () async {
    await stack.insertAlarm(label: 'Work');

    final ReliabilityData data = await read(
      cameraGate: FakeCameraStatusGate(CameraPermissionOutcome.denied),
    );

    expect(data.snapshot.camera, CapabilityState.denied);
  });

  test('disabled alarms are not counted', () async {
    await stack.insertAlarm(label: 'Off', enabled: false);

    final ReliabilityData data = await read();

    expect(data.enabledCount, 0);
    expect(data.report.overall, ReliabilityOverall.reliable);
  });

  test('bridge failures propagate to the caller', () async {
    await expectLater(
      read(
        bridge: FakePermissionSystemBridge()..failReads = true,
      ),
      throwsA(isA<PermissionBridgeException>()),
    );
  });
}
