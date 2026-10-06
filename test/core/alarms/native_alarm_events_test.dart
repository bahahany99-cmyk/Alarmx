import 'package:alarmx/core/alarms/native_alarm_events.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

// Routing tests for the native -> Dart stop handoff: simulated platform
// messages on the shared channel must reach `onAlarmStopped` with the
// alarm id and fired trigger, while anything malformed stays silent.
// No device or platform views are involved.

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const String channelName = 'com.alarmx.app.alarmx/alarm_scheduler';
  const StandardMethodCodec codec = StandardMethodCodec();
  final NativeAlarmEvents events = NativeAlarmEvents();
  final List<(int, DateTime)> received = <(int, DateTime)>[];

  Future<void> deliverNativeCall(String method, Object? args) {
    return TestDefaultBinaryMessengerBinding
        .instance.defaultBinaryMessenger
        .handlePlatformMessage(
      channelName,
      codec.encodeMethodCall(MethodCall(method, args)),
      (ByteData? data) {},
    );
  }

  setUp(() {
    received.clear();
    events.onAlarmStopped = (int alarmId, DateTime firedTriggerAt) async {
      received.add((alarmId, firedTriggerAt));
    };
    events.attach();
  });

  tearDown(() {
    events.detach();
    events.onAlarmStopped = null;
  });

  test('stop report reaches the handler with id and trigger', () async {
    final DateTime trigger = DateTime(2026, 10, 6, 7, 30);

    await deliverNativeCall('onAlarmStopped', <String, Object?>{
      'alarmId': 5,
      'triggerAtMillis': trigger.millisecondsSinceEpoch,
    });

    expect(received, <(int, DateTime)>[(5, trigger)]);
  });

  test('unknown methods are ignored', () async {
    await deliverNativeCall('scheduleExactAlarm', <String, Object?>{
      'alarmId': 5,
      'triggerAtMillis': 1,
    });

    expect(received, isEmpty);
  });

  test('malformed payloads are ignored without throwing', () async {
    await deliverNativeCall('onAlarmStopped', null);
    await deliverNativeCall('onAlarmStopped', <String, Object?>{});
    await deliverNativeCall(
        'onAlarmStopped', <String, Object?>{'alarmId': 'five'});
    await deliverNativeCall(
        'onAlarmStopped', <String, Object?>{'alarmId': 5});

    expect(received, isEmpty);
  });

  test('detached listener receives nothing', () async {
    events.detach();

    await deliverNativeCall('onAlarmStopped', <String, Object?>{
      'alarmId': 5,
      'triggerAtMillis': 1,
    });

    expect(received, isEmpty);
  });
}
