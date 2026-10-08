import 'package:alarmx/core/permissions/capability_state.dart';
import 'package:alarmx/core/permissions/permission_snapshot.dart';
import 'package:flutter_test/flutter_test.dart';

// Pure mapping tests: native snapshot maps + camera state become typed
// capability states. No platform channels.

void main() {
  Map<String, Object?> native({
    int sdkInt = 34,
    bool? master = true,
    bool? postGranted = true,
    bool? channel = true,
    bool? exact = true,
    bool? fullScreen = true,
    bool? exempt = true,
    bool? boot = true,
  }) {
    return <String, Object?>{
      'sdkInt': sdkInt,
      'notificationsEnabled': master,
      'postNotificationsGranted': postGranted,
      'ringingChannelEnabled': channel,
      'canScheduleExactAlarms': exact,
      'fullScreenIntentAllowed': fullScreen,
      'batteryExempt': exempt,
      'bootReceiverEnabled': boot,
    };
  }

  PermissionSnapshot map(
    Map<String, Object?> map, [
    CapabilityState camera = CapabilityState.granted,
  ]) =>
      PermissionSnapshot.fromSystem(native: map, camera: camera);

  test('modern device with everything on maps to granted', () {
    final PermissionSnapshot snapshot = map(native());
    expect(snapshot.sdkInt, 34);
    expect(snapshot.notifications, CapabilityState.granted);
    expect(snapshot.exactAlarm, CapabilityState.granted);
    expect(snapshot.fullScreenIntent, CapabilityState.granted);
    expect(snapshot.boot, CapabilityState.granted);
    expect(snapshot.battery, CapabilityState.granted);
    expect(snapshot.camera, CapabilityState.granted);
  });

  test('below API 31 exact alarm and full screen are not applicable', () {
    final PermissionSnapshot snapshot = map(
      native(
        sdkInt: 30,
        postGranted: null,
        fullScreen: null,
      ),
    );
    expect(snapshot.exactAlarm, CapabilityState.notApplicable);
    expect(snapshot.fullScreenIntent, CapabilityState.notApplicable);
    // POST_NOTIFICATIONS does not exist below 33: a null leg is fine.
    expect(snapshot.notifications, CapabilityState.granted);
  });

  test('API 33 keeps full screen not applicable', () {
    final PermissionSnapshot snapshot = map(
      native(sdkInt: 33, fullScreen: null),
    );
    expect(snapshot.exactAlarm, CapabilityState.granted);
    expect(snapshot.fullScreenIntent, CapabilityState.notApplicable);
  });

  test('any notification leg off means denied', () {
    expect(
      map(native(master: false)).notifications,
      CapabilityState.denied,
    );
    expect(
      map(native(postGranted: false)).notifications,
      CapabilityState.denied,
    );
    expect(
      map(native(channel: false)).notifications,
      CapabilityState.denied,
    );
  });

  test('exact alarm and full screen denials map to denied', () {
    expect(map(native(exact: false)).exactAlarm, CapabilityState.denied);
    expect(
      map(native(fullScreen: false)).fullScreenIntent,
      CapabilityState.denied,
    );
  });

  test('disabled boot receiver is unavailable, not denied', () {
    expect(map(native(boot: false)).boot, CapabilityState.unavailable);
  });

  test('active battery optimization is denied (recommended dimension '
      'lives in the item descriptor)', () {
    expect(map(native(exempt: false)).battery, CapabilityState.denied);
  });

  test('camera state passes through verbatim', () {
    for (final CapabilityState state in CapabilityState.values) {
      expect(map(native(), state).camera, state);
    }
  });

  test('missing keys degrade to unknown without throwing', () {
    final PermissionSnapshot snapshot =
        map(<String, Object?>{}, CapabilityState.restricted);
    expect(snapshot.sdkInt, -1);
    expect(snapshot.notifications, CapabilityState.unknown);
    expect(snapshot.exactAlarm, CapabilityState.unknown);
    expect(snapshot.fullScreenIntent, CapabilityState.unknown);
    expect(snapshot.boot, CapabilityState.unknown);
    expect(snapshot.battery, CapabilityState.unknown);
    expect(snapshot.camera, CapabilityState.restricted);
  });

  test('mistyped values degrade to unknown without throwing', () {
    final PermissionSnapshot snapshot = map(<String, Object?>{
      'sdkInt': 'thirty-four',
      'notificationsEnabled': 'yes',
      'postNotificationsGranted': 1,
      'ringingChannelEnabled': 1,
      'canScheduleExactAlarms': 'true',
      'fullScreenIntentAllowed': 0,
      'batteryExempt': 'exempt',
      'bootReceiverEnabled': <bool>[true],
    });
    expect(snapshot.sdkInt, -1);
    expect(snapshot.notifications, CapabilityState.unknown);
    expect(snapshot.exactAlarm, CapabilityState.unknown);
    expect(snapshot.fullScreenIntent, CapabilityState.unknown);
    expect(snapshot.boot, CapabilityState.unknown);
    expect(snapshot.battery, CapabilityState.unknown);
  });

  test('missing sdkInt keeps version-independent probes working', () {
    final Map<String, Object?> raw = native(exempt: false, boot: false);
    raw.remove('sdkInt');
    final PermissionSnapshot snapshot = map(raw);
    expect(snapshot.sdkInt, -1);
    expect(snapshot.exactAlarm, CapabilityState.unknown);
    expect(snapshot.fullScreenIntent, CapabilityState.unknown);
    expect(snapshot.battery, CapabilityState.denied);
    expect(snapshot.boot, CapabilityState.unavailable);
  });

  test('unknown factory reports all-unknown plus the camera state', () {
    final PermissionSnapshot snapshot = PermissionSnapshot.unknown(
      camera: CapabilityState.denied,
    );
    expect(snapshot.sdkInt, -1);
    expect(snapshot.notifications, CapabilityState.unknown);
    expect(snapshot.exactAlarm, CapabilityState.unknown);
    expect(snapshot.fullScreenIntent, CapabilityState.unknown);
    expect(snapshot.boot, CapabilityState.unknown);
    expect(snapshot.battery, CapabilityState.unknown);
    expect(snapshot.camera, CapabilityState.denied);
  });
}
