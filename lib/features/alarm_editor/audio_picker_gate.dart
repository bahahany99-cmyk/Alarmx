// Alarm-sound picker gate: local audio files + system ringtones.
//
// The custom-sound pickers open ONLY from the editor's sound section —
// never at startup, never unprompted. Both live behind [AudioPickerGate]
// so the editor is unit-testable with scripted URIs and CI never touches
// platform picker APIs.
//
// Contract: both methods return the picked URI string, or null when the
// user cancels, the platform fails, or no foreground activity exists
// (headless engine). Neither ever throws: platform errors degrade to
// null and the editor simply keeps its current sound.

import 'package:flutter/services.dart';

/// Opens the system pickers for a custom alarm sound.
abstract class AudioPickerGate {
  /// Opens the system file picker (local audio via SAF). Returns the
  /// picked content URI string, or null on cancel/failure. Never throws.
  Future<String?> pickLocalAudio();

  /// Opens the system ringtone picker (alarm type), preselecting
  /// [existingUri] when set. Returns the picked URI string, or null on
  /// cancel/failure. Never throws.
  Future<String?> pickSystemRingtone({String? existingUri});
}

/// [AudioPickerGate] over the shared alarm-scheduler channel.
class MethodChannelAudioPicker implements AudioPickerGate {
  const MethodChannelAudioPicker([MethodChannel? channel])
      : _channel = channel ??
            const MethodChannel('com.alarmx.app.alarmx/alarm_scheduler');

  final MethodChannel _channel;

  @override
  Future<String?> pickLocalAudio() async {
    try {
      return await _channel.invokeMethod<String>('pickAudioFile');
    } catch (_) {
      return null;
    }
  }

  @override
  Future<String?> pickSystemRingtone({String? existingUri}) async {
    try {
      return await _channel.invokeMethod<String>(
        'pickSystemRingtone',
        <String, Object?>{'existingUri': existingUri},
      );
    } catch (_) {
      return null;
    }
  }
}
