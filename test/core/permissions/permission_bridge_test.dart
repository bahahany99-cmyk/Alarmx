// Tests for MethodChannelPermissionBridge against a mocked channel:
// snapshot delivery shapes, error mapping, and settings-action results.

import 'package:alarmx/core/permissions/permission_bridge.dart';
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

  group('readSnapshot', () {
    test('delivers the native map', () async {
      handler = (MethodCall call) {
        expect(call.method, 'getPermissionSnapshot');
        return <String, Object?>{'sdkInt': 34, 'batteryExempt': true};
      };
      final Map<String, Object?> snapshot =
          await MethodChannelPermissionBridge(channel).readSnapshot();
      expect(snapshot['sdkInt'], 34);
      expect(snapshot['batteryExempt'], true);
      expect(calls.single.method, 'getPermissionSnapshot');
    });

    test('null reply throws PermissionBridgeException', () async {
      handler = (_) => null;
      expect(
        MethodChannelPermissionBridge(channel).readSnapshot(),
        throwsA(isA<PermissionBridgeException>()),
      );
    });

    test('non-string keys throw PermissionBridgeException', () async {
      handler = (_) => <Object?, Object?>{7: true};
      expect(
        MethodChannelPermissionBridge(channel).readSnapshot(),
        throwsA(isA<PermissionBridgeException>()),
      );
    });

    test('platform errors throw PermissionBridgeException', () async {
      handler = (_) {
        throw PlatformException(code: 'NATIVE_ERROR', message: 'boom');
      };
      expect(
        MethodChannelPermissionBridge(channel).readSnapshot(),
        throwsA(
          isA<PermissionBridgeException>().having(
            (PermissionBridgeException e) => e.message,
            'message',
            'boom',
          ),
        ),
      );
    });
  });

  group('openSettings', () {
    test('sends the target name and returns the native verdict', () async {
      handler = (MethodCall call) {
        expect(call.method, 'openSystemSettings');
        expect(call.arguments, <String, Object?>{'target': 'battery'});
        return true;
      };
      final bool launched = await MethodChannelPermissionBridge(channel)
          .openSettings(PermissionSettingsTarget.battery);
      expect(launched, isTrue);
    });

    test('false stays false: failures are never upgraded', () async {
      handler = (_) => false;
      final bool launched = await MethodChannelPermissionBridge(channel)
          .openSettings(PermissionSettingsTarget.exactAlarm);
      expect(launched, isFalse);
    });

    test('null reply degrades to false', () async {
      handler = (_) => null;
      final bool launched = await MethodChannelPermissionBridge(channel)
          .openSettings(PermissionSettingsTarget.notifications);
      expect(launched, isFalse);
    });

    test('platform errors degrade to false without throwing', () async {
      handler = (_) {
        throw PlatformException(code: 'NATIVE_ERROR');
      };
      final bool launched = await MethodChannelPermissionBridge(channel)
          .openSettings(PermissionSettingsTarget.appDetails);
      expect(launched, isFalse);
    });
  });
}
