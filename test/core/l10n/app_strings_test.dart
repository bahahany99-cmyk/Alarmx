import 'package:alarmx/core/l10n/app_strings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppLanguage', () {
    test('normalize keeps supported codes', () {
      expect(AppLanguage.normalize('ar'), 'ar');
      expect(AppLanguage.normalize('en'), 'en');
    });

    test('normalize falls back to Arabic', () {
      expect(AppLanguage.normalize(null), 'ar');
      expect(AppLanguage.normalize(''), 'ar');
      expect(AppLanguage.normalize('fr'), 'ar');
    });
  });

  group('AppStrings', () {
    test('both tables define the same keys, all non-empty', () {
      final AppStrings ar = AppStrings.forCode('ar');
      final AppStrings en = AppStrings.forCode('en');
      expect(AppStrings.keys, isNotEmpty);
      for (final String key in AppStrings.keys) {
        expect(ar.text(key), isNotEmpty, reason: 'ar:$key');
        expect(en.text(key), isNotEmpty, reason: 'en:$key');
        expect(ar.text(key), isNot(equals(key)), reason: 'ar:$key');
        expect(en.text(key), isNot(equals(key)), reason: 'en:$key');
      }
    });

    test('forCode resolves Arabic values', () {
      final AppStrings strings = AppStrings.forCode('ar');
      expect(strings.homeTitle, 'المنبهات');
      expect(strings.save, 'حفظ');
      expect(strings.repeatDaily, 'يومي');
      expect(strings.daySun, 'الأحد');
    });

    test('forCode resolves English values', () {
      final AppStrings strings = AppStrings.forCode('en');
      expect(strings.homeTitle, 'Alarms');
      expect(strings.save, 'Save');
      expect(strings.repeatDaily, 'Daily');
      expect(strings.daySun, 'Sun');
    });

    test('forCode falls back to Arabic for unknown codes', () {
      expect(AppStrings.forCode(null).homeTitle, 'المنبهات');
      expect(AppStrings.forCode('fr').homeTitle, 'المنبهات');
    });

    test('text falls back to the key itself when missing', () {
      expect(AppStrings.forCode('en').text('no.such.key'), 'no.such.key');
      expect(AppStrings.forCode('ar').text('no.such.key'), 'no.such.key');
    });

    testWidgets('of resolves from the ambient ar locale',
        (WidgetTester tester) async {
      late final AppStrings strings;
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('ar'),
          home: Builder(
            builder: (BuildContext context) {
              strings = AppStrings.of(context);
              return const SizedBox();
            },
          ),
        ),
      );
      expect(strings.homeTitle, 'المنبهات');
    });

    testWidgets('of resolves from the ambient en locale',
        (WidgetTester tester) async {
      late final AppStrings strings;
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('en'),
          home: Builder(
            builder: (BuildContext context) {
              strings = AppStrings.of(context);
              return const SizedBox();
            },
          ),
        ),
      );
      expect(strings.homeTitle, 'Alarms');
    });
  });
}
