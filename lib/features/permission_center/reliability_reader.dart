// Shared reliability assembly (Phase 7).
//
// [readReliability] is the single place that combines the native snapshot,
// the just-in-time camera status check, and the alarm/mission state into
// [ReliabilityData]. Both the Permission Center screen and the Home
// indicator use it, so the two can never disagree.

import 'package:alarmx/core/database/database.dart';
import 'package:alarmx/core/models/models.dart';
import 'package:alarmx/core/permissions/capability_state.dart';
import 'package:alarmx/core/permissions/permission_bridge.dart';
import 'package:alarmx/core/permissions/permission_snapshot.dart';
import 'package:alarmx/core/repositories/alarm_repository.dart';
import 'package:alarmx/features/missions/mission_config.dart';
import 'package:alarmx/features/missions/mission_service.dart';
import 'package:alarmx/features/missions/permissions/camera_permission.dart';
import 'package:alarmx/features/permission_center/reliability_calculator.dart';

/// Mission types that need the camera when executed.
const Set<MissionType> cameraMissionTypes = <MissionType>{
  MissionType.qr,
  MissionType.barcode,
  MissionType.photo,
};

/// Everything reliability surfaces render from a single read.
class ReliabilityData {
  const ReliabilityData({
    required this.snapshot,
    required this.report,
    required this.enabledCount,
    required this.cameraRelevant,
  });

  final PermissionSnapshot snapshot;
  final ReliabilityReport report;
  final int enabledCount;
  final bool cameraRelevant;
}

/// Reads the native snapshot plus the camera status (check-only, never a
/// request), scans enabled alarms for camera missions, and computes the
/// report. Throws the first failure: callers render an error state (the
/// center) or a neutral indicator (Home). Never requests camera access.
Future<ReliabilityData> readReliability({
  required PermissionSystemBridge bridge,
  required CameraPermissionGate cameraGate,
  required AlarmRepository alarms,
  required MissionService missions,
}) async {
  final Map<String, Object?> native = await bridge.readSnapshot();
  final CameraPermissionOutcome outcome =
      await cameraGate.checkCameraStatus();
  final CapabilityState camera;
  switch (outcome) {
    case CameraPermissionOutcome.granted:
      camera = CapabilityState.granted;
    case CameraPermissionOutcome.permanentlyDenied:
      // The system will not prompt again: settings-only recovery.
      camera = CapabilityState.restricted;
    case CameraPermissionOutcome.denied:
      camera = CapabilityState.denied;
  }
  final PermissionSnapshot snapshot =
      PermissionSnapshot.fromSystem(native: native, camera: camera);
  // One-shot read: never `.first` on a watch stream (it does not complete
  // under fake async and would hang the loading state forever).
  final List<Alarm> enabled = await alarms.getEnabledAlarms();
  bool relevant = false;
  for (final Alarm alarm in enabled) {
    final AlarmMissions alarmMissions =
        await missions.getMissionsForAlarm(alarm.id);
    if (alarmMissions.entries
        .any((MissionEntry entry) => cameraMissionTypes.contains(entry.type))) {
      relevant = true;
      break;
    }
  }
  final ReliabilityReport report = computeReliability(
    ReliabilityInput(
      snapshot: snapshot,
      hasEnabledAlarms: enabled.isNotEmpty,
      cameraRelevant: relevant,
    ),
  );
  return ReliabilityData(
    snapshot: snapshot,
    report: report,
    enabledCount: enabled.length,
    cameraRelevant: relevant,
  );
}
