// PIN protection service (Phase 5).
//
// Salted, iterated, one-way PIN verification over the existing
// `AppSettings.pinEnabled` / `pinHash` columns (no schema change):
//   - A PIN is 4-12 ASCII digits ([isValidPin]). Anything else is
//     rejected before it ever reaches storage.
//   - Storage is a versioned encoding inside the existing `pinHash`
//     TEXT column: `v1$<iterations>$<base64url salt>$<base64url hash>`.
//     The salt is 16 cryptographically random bytes ([Random.secure];
//     never hard-coded); the hash is SHA-256 iterated
//     [kPinHashIterations] times over `salt || utf8(pin)`. The count is
//     calibrated for sub-second unlock on-device (UX-bound): it raises
//     brute-force cost but is not the security boundary — an attacker
//     who can read the settings row can also flip `pinEnabled`.
//   - Verification recomputes and compares in constant time. Unknown
//     versions, malformed encodings, and absurd iteration counts fail
//     closed (verify returns false, never throws).
//   - Effective protection ([isPinEnabled]) requires the flag AND a
//     parseable hash. A corrupt hash fails open to "disabled": an
//     attacker with database access can flip the flag directly anyway,
//     while failing closed would permanently lock the owner out of
//     their own protected actions with no recovery path.
//
// The plaintext PIN is never persisted, never logged, and never leaves
// this API except as the caller's own in-memory argument. Encoded
// hashes are never logged either.

import 'dart:convert' show base64Url, utf8;
import 'dart:math' show Random;

import 'package:alarmx/core/database/database.dart';
import 'package:alarmx/core/repositories/app_settings_repository.dart';
import 'package:crypto/crypto.dart' show sha256;
import 'package:drift/drift.dart' show Value;

/// Minimum PIN length (digits).
const int kPinMinLength = 4;

/// Maximum PIN length (digits).
const int kPinMaxLength = 12;

/// Salt length in bytes.
const int kPinSaltLength = 16;

/// SHA-256 iterations per hash/verification.
const int kPinHashIterations = 10000;

/// PIN protection over `AppSettings`; see the file docs.
class PinService {
  PinService(this._settings, {List<int> Function(int length)? saltGenerator})
      : _saltGenerator = saltGenerator ?? _secureSalt;

  final AppSettingsRepository _settings;
  final List<int> Function(int length) _saltGenerator;

  static List<int> _secureSalt(int length) {
    final Random random = Random.secure();
    return List<int>.generate(length, (_) => random.nextInt(256));
  }

  /// Whether [pin] is usable: 4-12 ASCII digits, nothing else.
  static bool isValidPin(String pin) {
    if (pin.length < kPinMinLength || pin.length > kPinMaxLength) {
      return false;
    }
    for (int i = 0; i < pin.length; i++) {
      final int code = pin.codeUnitAt(i);
      if (code < 0x30 || code > 0x39) {
        return false;
      }
    }
    return true;
  }

  /// Effective protection: the flag is on and a parseable hash is
  /// stored (see the file docs for the corrupt-hash rule).
  Future<bool> isPinEnabled() async {
    final AppSetting settings = await _settings.getSettings();
    if (!settings.pinEnabled) {
      return false;
    }
    return _ParsedPinHash.tryParse(settings.pinHash) != null;
  }

  /// Whether [pin] verifies against the stored hash. Fails closed on
  /// any storage or format problem; never throws for those.
  Future<bool> verifyPin(String pin) async {
    final AppSetting settings = await _settings.getSettings();
    final _ParsedPinHash? parsed =
        _ParsedPinHash.tryParse(settings.pinHash);
    if (parsed == null) {
      return false;
    }
    final List<int> candidate =
        _stretch(pin, parsed.salt, parsed.iterations);
    return _constantTimeEquals(candidate, parsed.hash);
  }

  /// Sets (and enables) the PIN. Returns a message key on failure,
  /// `null` on success.
  Future<String?> setPin({
    required String pin,
    required String confirmation,
  }) async {
    if (!isValidPin(pin)) {
      return 'msgPinInvalid';
    }
    if (pin != confirmation) {
      return 'msgPinMismatch';
    }
    await _storePin(pin);
    return null;
  }

  /// Changes the PIN after authenticating [current]. Returns a message
  /// key on failure, `null` on success.
  Future<String?> changePin({
    required String current,
    required String pin,
    required String confirmation,
  }) async {
    if (!await verifyPin(current)) {
      return 'msgPinIncorrect';
    }
    return setPin(pin: pin, confirmation: confirmation);
  }

  /// Disables the PIN after authenticating [current] (the stored hash
  /// is cleared). Returns a message key on failure, `null` on success.
  Future<String?> disablePin(String current) async {
    if (!await verifyPin(current)) {
      return 'msgPinIncorrect';
    }
    // Ensure the singleton row exists: updateSettings writes nothing on
    // an empty table, and a PIN write may precede any settings read.
    await _settings.getSettings();
    await _settings.updateSettings(
      const AppSettingsCompanion(
        pinEnabled: Value<bool>(false),
        pinHash: Value<String?>(null),
      ),
    );
    return null;
  }

  Future<void> _storePin(String pin) async {
    final List<int> salt = _saltGenerator(kPinSaltLength);
    final List<int> hash = _stretch(pin, salt, kPinHashIterations);
    final String encoded = 'v1\$$kPinHashIterations\$'
        '${_encode(salt)}\$${_encode(hash)}';
    // Ensure the singleton row exists (see disablePin).
    await _settings.getSettings();
    await _settings.updateSettings(
      AppSettingsCompanion(
        pinEnabled: const Value<bool>(true),
        pinHash: Value<String?>(encoded),
      ),
    );
  }

  static List<int> _stretch(String pin, List<int> salt, int iterations) {
    List<int> block = <int>[...salt, ...utf8.encode(pin)];
    for (int i = 0; i < iterations; i++) {
      block = sha256.convert(block).bytes;
    }
    return block;
  }

  static bool _constantTimeEquals(List<int> a, List<int> b) {
    if (a.length != b.length) {
      return false;
    }
    int diff = 0;
    for (int i = 0; i < a.length; i++) {
      diff |= a[i] ^ b[i];
    }
    return diff == 0;
  }

  static String _encode(List<int> bytes) => base64Url.encode(bytes);
}

/// Parsed `v1` PIN hash encoding; `null` when unparseable.
class _ParsedPinHash {
  const _ParsedPinHash({
    required this.salt,
    required this.hash,
    required this.iterations,
  });

  final List<int> salt;
  final List<int> hash;
  final int iterations;

  static _ParsedPinHash? tryParse(String? encoded) {
    if (encoded == null) {
      return null;
    }
    final List<String> parts = encoded.split('\$');
    if (parts.length != 4 || parts[0] != 'v1') {
      return null;
    }
    final int? iterations = int.tryParse(parts[1]);
    if (iterations == null || iterations < 1 || iterations > 1000000) {
      return null;
    }
    try {
      final List<int> salt = base64Url.decode(parts[2]);
      final List<int> hash = base64Url.decode(parts[3]);
      if (salt.isEmpty || hash.isEmpty) {
        return null;
      }
      return _ParsedPinHash(
        salt: salt,
        hash: hash,
        iterations: iterations,
      );
    } catch (_) {
      return null;
    }
  }
}
