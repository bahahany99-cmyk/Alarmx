// Native permission/settings bridge for the Permission Center (Phase 7).
//
// Reuses the shared `com.alarmx.app.alarmx/alarm_scheduler` MethodChannel
// (no second channel): the native handler already layers non-scheduling
// methods next to the scheduler ones. Two methods:
//   - `getPermissionSnapshot` args {} -> native snapshot map (never null).
//   - `openSystemSettings` args {target} -> bool launched.
// Target names are [PermissionSettingsTarget.name] on both sides.

import 'package:flutter/services.dart';

/// System settings page the center can ask Android to open.
enum PermissionSettingsTarget {
  /// App notification settings (channel page when resolvable).
  notifications,

  /// Exact-alarm access page (API 31+).
  exactAlarm,

  /// Full-screen-intent page (API 34+).
  fullScreen,

  /// Battery-optimization settings list.
  battery,

  /// Full-screen-intent entry under Special App Access (API 34+): the
  /// permission's app list, used when the per-app page bounces on OEM
  /// skins. Falls back to app-details natively when unresolvable.
  specialAppAccess,

  /// General app-details page (also the native fallback).
  appDetails,
}

/// Thrown when the native snapshot cannot be read. Screens catch this and
/// render an error state with retry; it never surfaces a guessed state.
class PermissionBridgeException implements Exception {
  const PermissionBridgeException(this.message);

  final String message;

  @override
  String toString() => 'PermissionBridgeException: $message';
}

/// Reads the native permission snapshot and opens system settings pages.
abstract class PermissionSystemBridge {
  /// Reads the native snapshot map. Throws [PermissionBridgeException]
  /// when the platform call fails or the reply is unusable.
  Future<Map<String, Object?>> readSnapshot();

  /// Asks Android to open [target]. Returns whether a settings page was
  /// actually launched. Never throws: every failure degrades to `false`
  /// so the UI can report it honestly.
  Future<bool> openSettings(PermissionSettingsTarget target);
}

/// [PermissionSystemBridge] over the shared scheduler MethodChannel.
class MethodChannelPermissionBridge implements PermissionSystemBridge {
  const MethodChannelPermissionBridge([MethodChannel? channel])
      : _channel = channel ??
            const MethodChannel('com.alarmx.app.alarmx/alarm_scheduler');

  final MethodChannel _channel;

  @override
  Future<Map<String, Object?>> readSnapshot() async {
    final Map<Object?, Object?>? reply;
    try {
      reply = await _channel.invokeMethod<Map<Object?, Object?>>(
        'getPermissionSnapshot',
      );
    } on PlatformException catch (e) {
      throw PermissionBridgeException(e.message ?? e.code);
    } on MissingPluginException catch (e) {
      throw PermissionBridgeException(e.message ?? 'missing plugin');
    }
    if (reply == null) {
      throw const PermissionBridgeException('empty snapshot reply');
    }
    final Map<String, Object?> snapshot = <String, Object?>{};
    for (final MapEntry<Object?, Object?> entry in reply.entries) {
      final Object? key = entry.key;
      if (key is! String) {
        throw const PermissionBridgeException('malformed snapshot reply');
      }
      snapshot[key] = entry.value;
    }
    return snapshot;
  }

  @override
  Future<bool> openSettings(PermissionSettingsTarget target) async {
    try {
      final bool? launched = await _channel.invokeMethod<bool>(
        'openSystemSettings',
        <String, Object?>{'target': target.name},
      );
      return launched ?? false;
    } catch (_) {
      return false;
    }
  }
}
