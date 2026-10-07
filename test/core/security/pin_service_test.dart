import 'package:alarmx/core/database/database.dart';
import 'package:alarmx/core/security/pin_service.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';

import '../../support/test_doubles.dart';

// PinService tests: real in-memory settings, fixed salt unless stated.

PinService fixedSaltService(TestStack stack) {
  return PinService(
    stack.settings,
    saltGenerator: (_) => List<int>.filled(16, 7),
  );
}

void main() {
  late TestStack stack;

  setUp(() {
    stack = TestStack();
  });

  group('isValidPin', () {
    test('accepts 4, 6 and 12 digit PINs', () {
      expect(PinService.isValidPin('1234'), isTrue);
      expect(PinService.isValidPin('123456'), isTrue);
      expect(PinService.isValidPin('123456789012'), isTrue);
    });

    test('rejects short, long, empty and non-digit PINs', () {
      expect(PinService.isValidPin(''), isFalse);
      expect(PinService.isValidPin('123'), isFalse);
      expect(PinService.isValidPin('1234567890123'), isFalse);
      expect(PinService.isValidPin('12a4'), isFalse);
      expect(PinService.isValidPin('12 4'), isFalse);
      expect(PinService.isValidPin('١٢٣٤'), isFalse);
    });
  });

  group('setPin + verifyPin', () {
    test('disabled by default; set enables and verifies', () async {
      final PinService pin = fixedSaltService(stack);
      expect(await pin.isPinEnabled(), isFalse);
      expect(await pin.verifyPin('1234'), isFalse);

      expect(
        await pin.setPin(pin: '1234', confirmation: '1234'),
        isNull,
      );
      expect(await pin.isPinEnabled(), isTrue);
      expect(await pin.verifyPin('1234'), isTrue);
      expect(await pin.verifyPin('0000'), isFalse);
    });

    test('mismatch keeps the PIN disabled', () async {
      final PinService pin = fixedSaltService(stack);
      expect(
        await pin.setPin(pin: '1234', confirmation: '5678'),
        'msgPinMismatch',
      );
      expect(await pin.isPinEnabled(), isFalse);
    });

    test('invalid PIN is rejected', () async {
      final PinService pin = fixedSaltService(stack);
      expect(
        await pin.setPin(pin: '12', confirmation: '12'),
        'msgPinInvalid',
      );
      expect(await pin.isPinEnabled(), isFalse);
    });

    test('stored encoding is versioned and never the plaintext', () async {
      final PinService pin = fixedSaltService(stack);
      await pin.setPin(pin: '1234', confirmation: '1234');
      final AppSetting stored = await stack.settings.getSettings();
      expect(stored.pinEnabled, isTrue);
      final String? hash = stored.pinHash;
      expect(hash, isNotNull);
      expect(hash, isNot('1234'));
      final List<String> parts = hash!.split('\$');
      expect(parts.length, 4);
      expect(parts[0], 'v1');
      expect(parts[1], '$kPinHashIterations');
      expect(parts[2].isNotEmpty && parts[3].isNotEmpty, isTrue);
    });

    test('same PIN verifies after a fresh service read', () async {
      await fixedSaltService(stack)
          .setPin(pin: '1234', confirmation: '1234');
      expect(
        await fixedSaltService(stack).verifyPin('1234'),
        isTrue,
      );
    });

    test('different PINs produce different encodings', () async {
      final PinService pin = fixedSaltService(stack);
      await pin.setPin(pin: '1234', confirmation: '1234');
      final String? first = (await stack.settings.getSettings()).pinHash;
      await pin.setPin(pin: '5678', confirmation: '5678');
      final String? second = (await stack.settings.getSettings()).pinHash;
      expect(first, isNotNull);
      expect(second, isNotNull);
      expect(first, isNot(second));
    });

    test('default generator salts randomly across stores', () async {
      final PinService pin = PinService(stack.settings);
      await pin.setPin(pin: '1234', confirmation: '1234');
      final String? first = (await stack.settings.getSettings()).pinHash;
      await pin.setPin(pin: '1234', confirmation: '1234');
      final String? second = (await stack.settings.getSettings()).pinHash;
      expect(first, isNot(second));
      expect(await pin.verifyPin('1234'), isTrue);
    });
  });

  group('changePin + disablePin', () {
    test('change requires the current PIN', () async {
      final PinService pin = fixedSaltService(stack);
      await pin.setPin(pin: '1234', confirmation: '1234');
      expect(
        await pin.changePin(
          current: '0000',
          pin: '5678',
          confirmation: '5678',
        ),
        'msgPinIncorrect',
      );
      expect(await pin.verifyPin('1234'), isTrue);

      expect(
        await pin.changePin(
          current: '1234',
          pin: '5678',
          confirmation: '5678',
        ),
        isNull,
      );
      expect(await pin.verifyPin('5678'), isTrue);
      expect(await pin.verifyPin('1234'), isFalse);
    });

    test('change validates the new PIN', () async {
      final PinService pin = fixedSaltService(stack);
      await pin.setPin(pin: '1234', confirmation: '1234');
      expect(
        await pin.changePin(
          current: '1234',
          pin: '12',
          confirmation: '12',
        ),
        'msgPinInvalid',
      );
      expect(await pin.verifyPin('1234'), isTrue);
    });

    test('disable requires the current PIN and clears the hash', () async {
      final PinService pin = fixedSaltService(stack);
      await pin.setPin(pin: '1234', confirmation: '1234');
      expect(await pin.disablePin('0000'), 'msgPinIncorrect');
      expect(await pin.isPinEnabled(), isTrue);

      expect(await pin.disablePin('1234'), isNull);
      expect(await pin.isPinEnabled(), isFalse);
      expect(await pin.verifyPin('1234'), isFalse);
      final AppSetting stored = await stack.settings.getSettings();
      expect(stored.pinHash, isNull);
    });
  });

  group('corrupt storage', () {
    test('garbage hash reads as disabled and never verifies', () async {
      await stack.settings.getSettings();
      await stack.settings.updateSettings(
        const AppSettingsCompanion(
          pinEnabled: Value<bool>(true),
          pinHash: Value<String?>('not-a-hash'),
        ),
      );
      final PinService pin = fixedSaltService(stack);
      expect(await pin.isPinEnabled(), isFalse);
      expect(await pin.verifyPin('1234'), isFalse);
    });

    test('unknown version and absurd iterations fail closed', () async {
      await stack.settings.getSettings();
      final PinService pin = fixedSaltService(stack);
      for (final String bad in <String>[
        'v2\$100000\$xx\$yy',
        'v1\$999999999\$xx\$yy',
        'v1\$0\$xx\$yy',
        'v1\$100000\$!!!\$!!!',
      ]) {
        await stack.settings.updateSettings(
          AppSettingsCompanion(
            pinEnabled: const Value<bool>(true),
            pinHash: Value<String?>(bad),
          ),
        );
        expect(await pin.isPinEnabled(), isFalse, reason: bad);
        expect(await pin.verifyPin('1234'), isFalse, reason: bad);
      }
    });
  });
}
