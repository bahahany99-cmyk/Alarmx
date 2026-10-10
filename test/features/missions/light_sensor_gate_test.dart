// Tests for MethodChannelLightSensor against a mocked channel: lux
// delivery shapes and the never-throw contract.

import 'package:alarmx/features/missions/light/light_sensor_gate.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const MethodChannel channel =
      MethodChannel('com.alarmx.app.alarmx/alarm_scheduler');

  TestWidgetsFlutterBinding.ensureInitialized();
  final TestDefaultBinaryMessengerBinding messenger =
      TestDefaultBinaryMessengerBinding.instance;

  final List<MethodCall> calls = <MethodCall>[];
  Object? Function(MethodCall call)? handler;

  setUp(() {
    calls.clear();
    handler = null;
    messenger.defaultBinaryMessenger.setMockMethodCallHandler(
      channel,
      (MethodCall call) async {
        calls.add(call);
        final Object? Function(MethodCall call)? current = handler;
        if (current == null) {
          return null;
        }
        return current(call);
      },
    );
  });

  tearDown(() {
    messenger.defaultBinaryMessenger.setMockMethodCallHandler(channel, null);
  });

  test('delivers the lux reading', () async {
    handler = (MethodCall call) {
      expect(call.method, 'getAmbientLightLux');
      return 120.0;
    };
    expect(
      await const MethodChannelLightSensor(channel).readLux(),
      120.0,
    );
    expect(calls.single.method, 'getAmbientLightLux');
  });

  test('integer readings convert to double', () async {
    handler = (_) => 120;
    expect(
      await const MethodChannelLightSensor(channel).readLux(),
      120.0,
    );
  });

  test('null reply means no sensor', () async {
    handler = (_) => null;
    expect(
      await const MethodChannelLightSensor(channel).readLux(),
      isNull,
    );
  });

  test('platform error degrades to null', () async {
    handler = (_) => throw PlatformException(code: 'NATIVE_ERROR');
    expect(
      await const MethodChannelLightSensor(channel).readLux(),
      isNull,
    );
  });
}
