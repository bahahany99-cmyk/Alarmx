// Tests for MethodChannelRingingBridge against a mocked channel:
// launch delivery shapes and the stop call (args + error propagation).

import 'package:alarmx/features/ringing_alarm/ringing_alarm_bridge.dart';
import 'package:alarmx/features/ringing_alarm/ringing_launch.dart';
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

  group('consumeRingingLaunch', () {
    test('delivers a native launch payload', () async {
      handler = (MethodCall call) {
        expect(call.method, 'getRingingLaunch');
        return <String, Object?>{'alarmId': 7, 'label': 'Morning'};
      };
      final RingingLaunch? launch =
          await MethodChannelRingingBridge(channel).consumeRingingLaunch();
      expect(launch, isNotNull);
      expect(launch!.alarmId, 7);
      expect(launch.label, 'Morning');
    });

    test('null reply means a normal start', () async {
      handler = (_) => null;
      final RingingLaunch? launch =
          await MethodChannelRingingBridge(channel).consumeRingingLaunch();
      expect(launch, isNull);
    });

    test('malformed reply degrades to null', () async {
      handler = (_) => <String, Object?>{'label': 'no id'};
      final RingingLaunch? launch =
          await MethodChannelRingingBridge(channel).consumeRingingLaunch();
      expect(launch, isNull);
    });

    test('channel errors degrade to null', () async {
      handler = (_) => throw PlatformException(code: 'NATIVE_ERROR');
      final RingingLaunch? launch =
          await MethodChannelRingingBridge(channel).consumeRingingLaunch();
      expect(launch, isNull);
    });
  });

  group('stopRingingAlarm', () {
    test('invokes the native stop with the alarm id', () async {
      handler = (_) => null;
      await MethodChannelRingingBridge(channel).stopRingingAlarm(9);
      expect(calls, hasLength(1));
      expect(calls.single.method, 'stopRingingAlarm');
      expect(
        calls.single.arguments,
        <String, Object?>{'alarmId': 9},
      );
    });

    test('stop errors propagate for the retry path', () async {
      handler = (_) => throw PlatformException(code: 'NATIVE_ERROR');
      await expectLater(
        MethodChannelRingingBridge(channel).stopRingingAlarm(9),
        throwsA(isA<PlatformException>()),
      );
    });
  });
}
