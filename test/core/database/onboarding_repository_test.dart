import 'package:alarmx/core/database/database.dart';
import 'package:alarmx/core/repositories/app_settings_repository.dart';
import 'package:alarmx/core/repositories/onboarding_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

// Onboarding side-table tests. Every test runs against a fresh in-memory
// database; the side table is created lazily by the repository itself.

void main() {
  late AppDatabase db;
  late OnboardingRepository onboarding;

  setUp(() {
    db = AppDatabase.connect(NativeDatabase.memory());
    onboarding = DriftOnboardingRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  group('onboarding repository', () {
    test('defaults to not completed on first read', () async {
      expect(await onboarding.isOnboardingComplete(), isFalse);
    });

    test('persists completion across repository instances', () async {
      await onboarding.setOnboardingComplete();
      // A second repository over the same database (as on relaunch) must
      // read the row back, not instance memory.
      final OnboardingRepository second = DriftOnboardingRepository(db);
      expect(await second.isOnboardingComplete(), isTrue);
    });

    test('completion is idempotent', () async {
      await onboarding.setOnboardingComplete();
      await onboarding.setOnboardingComplete();
      expect(await onboarding.isOnboardingComplete(), isTrue);
    });

    test('read and write interleave without losing the flag', () async {
      expect(await onboarding.isOnboardingComplete(), isFalse);
      await onboarding.setOnboardingComplete();
      expect(await onboarding.isOnboardingComplete(), isTrue);
    });

    test('side table coexists with typed tables', () async {
      final AppSettingsRepository settings =
          DriftAppSettingsRepository(db.appSettingsDao);
      expect((await settings.getSettings()).id, 1);
      expect(await onboarding.isOnboardingComplete(), isFalse);
      await onboarding.setOnboardingComplete();
      expect((await settings.getSettings()).id, 1);
      expect(await onboarding.isOnboardingComplete(), isTrue);
    });
  });
}
