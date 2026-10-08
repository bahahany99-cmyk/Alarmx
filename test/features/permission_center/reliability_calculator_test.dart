import 'package:alarmx/core/permissions/capability_state.dart';
import 'package:alarmx/core/permissions/permission_snapshot.dart';
import 'package:alarmx/features/permission_center/reliability_calculator.dart';
import 'package:flutter_test/flutter_test.dart';

// Pure calculator tests (STEP 11B, 14 cases): snapshot + alarm state in,
// deterministic verdict out. No platform channels.

void main() {
  PermissionSnapshot snapshot({
    CapabilityState notifications = CapabilityState.granted,
    CapabilityState exactAlarm = CapabilityState.granted,
    CapabilityState fullScreenIntent = CapabilityState.granted,
    CapabilityState boot = CapabilityState.granted,
    CapabilityState battery = CapabilityState.granted,
    CapabilityState camera = CapabilityState.granted,
  }) {
    return PermissionSnapshot(
      notifications: notifications,
      exactAlarm: exactAlarm,
      fullScreenIntent: fullScreenIntent,
      boot: boot,
      battery: battery,
      camera: camera,
      sdkInt: 34,
    );
  }

  ReliabilityReport report({
    PermissionSnapshot? snapshotOverride,
    bool hasEnabledAlarms = true,
    bool cameraRelevant = false,
  }) {
    return computeReliability(
      ReliabilityInput(
        snapshot: snapshotOverride ?? snapshot(),
        hasEnabledAlarms: hasEnabledAlarms,
        cameraRelevant: cameraRelevant,
      ),
    );
  }

  ReliabilityLevel levelOf(ReliabilityReport report, ReliabilityItemId id) =>
      report.levels[id]!;

  test('1: everything ready is reliable', () {
    final ReliabilityReport result = report();
    expect(result.overall, ReliabilityOverall.reliable);
    for (final ReliabilityItemId id in ReliabilityItemId.values) {
      expect(levelOf(result, id), ReliabilityLevel.ready, reason: '$id');
    }
  });

  test('2: missing notifications are critical with enabled alarms', () {
    final ReliabilityReport result = report(
      snapshotOverride: snapshot(notifications: CapabilityState.denied),
    );
    expect(
      levelOf(result, ReliabilityItemId.notifications),
      ReliabilityLevel.critical,
    );
    expect(result.overall, ReliabilityOverall.attentionRequired);
  });

  test('3: missing exact alarm is critical with enabled alarms', () {
    final ReliabilityReport result = report(
      snapshotOverride: snapshot(exactAlarm: CapabilityState.denied),
    );
    expect(
      levelOf(result, ReliabilityItemId.exactAlarm),
      ReliabilityLevel.critical,
    );
    expect(result.overall, ReliabilityOverall.attentionRequired);
  });

  test('4: missing full screen is advisory', () {
    final ReliabilityReport result = report(
      snapshotOverride: snapshot(fullScreenIntent: CapabilityState.denied),
    );
    expect(
      levelOf(result, ReliabilityItemId.fullScreen),
      ReliabilityLevel.advisory,
    );
    expect(result.overall, ReliabilityOverall.mostlyReady);
  });

  test('5: active battery optimization is advisory', () {
    final ReliabilityReport result = report(
      snapshotOverride: snapshot(battery: CapabilityState.denied),
    );
    expect(levelOf(result, ReliabilityItemId.battery), ReliabilityLevel.advisory);
    expect(result.overall, ReliabilityOverall.mostlyReady);
  });

  test('6: available boot capability is ready', () {
    final ReliabilityReport result = report();
    expect(levelOf(result, ReliabilityItemId.boot), ReliabilityLevel.ready);
    expect(result.overall, ReliabilityOverall.reliable);
  });

  test('7: camera is ready when no camera mission needs it', () {
    final ReliabilityReport result = report(
      snapshotOverride: snapshot(camera: CapabilityState.denied),
    );
    expect(levelOf(result, ReliabilityItemId.camera), ReliabilityLevel.ready);
    expect(result.overall, ReliabilityOverall.reliable);
  });

  test('8: required camera granted is ready', () {
    final ReliabilityReport result = report(cameraRelevant: true);
    expect(levelOf(result, ReliabilityItemId.camera), ReliabilityLevel.ready);
    expect(result.overall, ReliabilityOverall.reliable);
  });

  test('9: required camera denied is advisory, never critical', () {
    final ReliabilityReport result = report(
      snapshotOverride: snapshot(camera: CapabilityState.denied),
      cameraRelevant: true,
    );
    expect(levelOf(result, ReliabilityItemId.camera), ReliabilityLevel.advisory);
    expect(result.overall, ReliabilityOverall.mostlyReady);
  });

  test('10: multiple failures keep the worst levels', () {
    final ReliabilityReport result = report(
      snapshotOverride: snapshot(
        notifications: CapabilityState.denied,
        exactAlarm: CapabilityState.denied,
        battery: CapabilityState.denied,
      ),
    );
    expect(
      levelOf(result, ReliabilityItemId.notifications),
      ReliabilityLevel.critical,
    );
    expect(
      levelOf(result, ReliabilityItemId.exactAlarm),
      ReliabilityLevel.critical,
    );
    expect(levelOf(result, ReliabilityItemId.battery), ReliabilityLevel.advisory);
    expect(levelOf(result, ReliabilityItemId.fullScreen), ReliabilityLevel.ready);
    expect(result.overall, ReliabilityOverall.attentionRequired);
  });

  test('11: only the recommended battery issue is mostly ready', () {
    final ReliabilityReport result = report(
      snapshotOverride: snapshot(battery: CapabilityState.denied),
    );
    expect(result.overall, ReliabilityOverall.mostlyReady);
    for (final ReliabilityItemId id in ReliabilityItemId.values) {
      if (id == ReliabilityItemId.battery) {
        continue;
      }
      expect(levelOf(result, id), ReliabilityLevel.ready, reason: '$id');
    }
  });

  test('12: only the conditional camera issue is mostly ready', () {
    final ReliabilityReport result = report(
      snapshotOverride: snapshot(camera: CapabilityState.restricted),
      cameraRelevant: true,
    );
    expect(levelOf(result, ReliabilityItemId.camera), ReliabilityLevel.advisory);
    expect(result.overall, ReliabilityOverall.mostlyReady);
  });

  test('13: no enabled alarms demotes critical findings to advisory', () {
    final ReliabilityReport result = report(
      snapshotOverride: snapshot(
        notifications: CapabilityState.denied,
        exactAlarm: CapabilityState.denied,
        fullScreenIntent: CapabilityState.denied,
        battery: CapabilityState.denied,
        boot: CapabilityState.unavailable,
      ),
      hasEnabledAlarms: false,
    );
    expect(
      levelOf(result, ReliabilityItemId.notifications),
      ReliabilityLevel.advisory,
    );
    expect(
      levelOf(result, ReliabilityItemId.exactAlarm),
      ReliabilityLevel.advisory,
    );
    expect(result.overall, ReliabilityOverall.mostlyReady);
  });

  test('14: unknown exact alarm with enabled alarms is critical', () {
    final ReliabilityReport result = report(
      snapshotOverride: snapshot(exactAlarm: CapabilityState.unknown),
    );
    expect(
      levelOf(result, ReliabilityItemId.exactAlarm),
      ReliabilityLevel.critical,
    );
    expect(result.overall, ReliabilityOverall.attentionRequired);
  });
}
