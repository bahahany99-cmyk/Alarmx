// Tests for MethodChannelAudioPicker against a mocked channel: URI
// delivery, cancellation (null), and the never-throw contract.

import 'package:alarmx/features/alarm_editor/audio_picker_gate.dart';
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

  group('pickLocalAudio', () {
    test('delivers the picked URI', () async {
      handler = (MethodCall call) {
        expect(call.method, 'pickAudioFile');
        return 'content://tones/x';
      };
      expect(
        await const MethodChannelAudioPicker(channel).pickLocalAudio(),
        'content://tones/x',
      );
      expect(calls.single.method, 'pickAudioFile');
    });

    test('cancel answers null', () async {
      handler = (_) => null;
      expect(
        await const MethodChannelAudioPicker(channel).pickLocalAudio(),
        isNull,
      );
    });

    test('platform error degrades to null', () async {
      handler = (_) => throw PlatformException(code: 'NATIVE_ERROR');
      expect(
        await const MethodChannelAudioPicker(channel).pickLocalAudio(),
        isNull,
      );
    });
  });

  group('pickSystemRingtone', () {
    test('sends the existing URI and delivers the pick', () async {
      handler = (MethodCall call) {
        expect(call.method, 'pickSystemRingtone');
        final Map<String, Object?> args =
            Map<String, Object?>.from(call.arguments as Map);
        expect(args['existingUri'], 'content://tones/old');
        return 'content://tones/new';
      };
      expect(
        await const MethodChannelAudioPicker(channel).pickSystemRingtone(
          existingUri: 'content://tones/old',
        ),
        'content://tones/new',
      );
    });

    test('cancel answers null', () async {
      handler = (_) => null;
      expect(
        await const MethodChannelAudioPicker(channel).pickSystemRingtone(),
        isNull,
      );
    });

    test('platform error degrades to null', () async {
      handler = (_) => throw PlatformException(code: 'NATIVE_ERROR');
      expect(
        await const MethodChannelAudioPicker(channel).pickSystemRingtone(),
        isNull,
      );
    });
  });
}
