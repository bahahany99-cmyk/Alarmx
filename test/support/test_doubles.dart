// Shared doubles for Phase 3 UI/controller tests.
//
// Pattern (same as the coordinator tests): a REAL in-memory Drift stack
// (repository + coordinator + controller) with a FAKE native scheduler that
// records calls. Widgets are therefore exercised against true persistence
// and scheduling orchestration; only the OS bridge is faked. Nothing here
// touches MethodChannels, files, or the clock beyond pinned values.
//
// Settling: every pump helper and test below uses [pumpSettle], which
// bounds settling to 30s of fake time. A pump that cannot settle in that
// window is a wedged test and must fail with its name instead of burning
// `pumpAndSettle`'s 10-minute default while CI appears hung.

import 'package:alarmx/core/alarms/alarm_controller.dart';
import 'package:alarmx/core/alarms/alarm_fire_config.dart';
import 'package:alarmx/core/alarms/native_alarm_scheduler.dart';
import 'package:alarmx/core/database/database.dart';
import 'package:alarmx/core/l10n/app_strings.dart';
import 'package:alarmx/core/models/models.dart';
import 'package:alarmx/core/repositories/alarm_repository.dart';
import 'package:alarmx/core/repositories/app_settings_repository.dart';
import 'package:alarmx/core/scheduling/alarm_scheduling_coordinator.dart';
import 'package:alarmx/features/alarm_editor/alarm_editor_screen.dart';
import 'package:alarmx/features/home/home_screen.dart';
import 'package:alarmx/main.dart';
import 'package:drift/drift.dart' show Value, driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

/// Records native calls and replays scripted failures.
///
/// Same shape as the fake in the coordinator tests (which stays untouched);
/// duplicated here so widget/controller tests do not import a `*_test.dart`
/// file.
class FakeNativeAlarmScheduler implements NativeAlarmScheduler {
  FakeNativeAlarmScheduler({this.canSchedule = true});

  bool canSchedule;
  Object? scheduleError;
  Object? cancelError;
  Object? checkError;
  final List<String> calls = <String>[];
  final List<int> scheduledIds = <int>[];
  final List<DateTime> scheduledTriggers = <DateTime>[];
  final List<AlarmFireConfig?> scheduledConfigs = <AlarmFireConfig?>[];
  final List<int> cancelledIds = <int>[];

  @override
  Future<void> scheduleExactAlarm({
    required int alarmId,
    required DateTime triggerAt,
    AlarmFireConfig? fireConfig,
  }) async {
    calls.add('schedule:$alarmId');
    if (scheduleError != null) {
      throw scheduleError!;
    }
    scheduledIds.add(alarmId);
    scheduledTriggers.add(triggerAt);
    scheduledConfigs.add(fireConfig);
  }

  @override
  Future<void> cancelAlarm({required int alarmId}) async {
    calls.add('cancel:$alarmId');
    if (cancelError != null) {
      throw cancelError!;
    }
    cancelledIds.add(alarmId);
  }

  @override
  Future<bool> canScheduleExactAlarms() async {
    if (checkError != null) {
      throw checkError!;
    }
    return canSchedule;
  }
}

/// Real in-memory engine stack for tests.
class TestStack {
  TestStack() {
    // Each widget test intentionally leaves its stack open (see the note in
    // the widget-test files); silence drift's concurrent-database warning.
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    db = AppDatabase.connect(NativeDatabase.memory());
    repository = DriftAlarmRepository(db.alarmDao);
    settings = DriftAppSettingsRepository(db.appSettingsDao);
    scheduler = FakeNativeAlarmScheduler();
    coordinator = AlarmSchedulingCoordinator(
      repository: repository,
      scheduler: scheduler,
    );
    controller = AlarmController(
      repository: repository,
      coordinator: coordinator,
    );
  }

  late final AppDatabase db;
  late final AlarmRepository repository;
  late final AppSettingsRepository settings;
  late final FakeNativeAlarmScheduler scheduler;
  late final AlarmSchedulingCoordinator coordinator;
  late final AlarmController controller;

  Future<void> close() => db.close();

  /// Inserts a daily alarm; returns its generated id.
  Future<int> insertAlarm({
    int hour = 7,
    int minute = 30,
    bool enabled = true,
    String? label,
    RepeatType repeatType = RepeatType.daily,
    DateTime? onceDate,
    int? repeatDays,
    bool vibrationEnabled = true,
  }) {
    return repository.createAlarm(
      AlarmsCompanion.insert(
        hour: hour,
        minute: minute,
        enabled: Value(enabled),
        label: Value(label),
        vibrationEnabled: Value(vibrationEnabled),
        repeatType: Value(repeatType.dbValue),
        onceDate: Value(onceDate),
        repeatDays: Value(repeatDays),
      ),
    );
  }

  /// Forces the stored UI language (creating the settings row first).
  Future<void> setLanguage(String code) async {
    await settings.getSettings();
    await settings.updateSettings(
      AppSettingsCompanion(language: Value(code)),
    );
  }
}

/// SDK localization delegates, shared by every pumped test app.
const List<LocalizationsDelegate<dynamic>> testDelegates =
    <LocalizationsDelegate<dynamic>>[
  GlobalMaterialLocalizations.delegate,
  GlobalWidgetsLocalizations.delegate,
  GlobalCupertinoLocalizations.delegate,
];

const List<Locale> testLocales = <Locale>[
  Locale(AppLanguage.arabic),
  Locale(AppLanguage.english),
];

/// Settles the pumped tree, failing fast instead of hanging.
///
/// Same quiescence loop as `pumpAndSettle` (100ms pumps until no frame is
/// scheduled), but bounded to 300 pumps: a tree that cannot settle in 30s
/// of fake time is a wedged test and must fail with its name instead of
/// burning the 10-minute default while CI looks hung. Every Phase 3
/// widget test must use this instead of bare `pumpAndSettle()`.
Future<void> pumpSettle(WidgetTester tester) async {
  for (int i = 0; i < 300; i++) {
    await tester.pump(const Duration(milliseconds: 100));
    if (!tester.binding.hasScheduledFrame) {
      return;
    }
  }
  throw StateError(
    'pumpSettle: tree did not settle within 30s of fake time.',
  );
}

/// Pumps the full production app shell in [language].
Future<void> pumpAlarmxApp(
  WidgetTester tester,
  TestStack stack, {
  String language = AppLanguage.english,
}) async {
  // Self-cleaning: unmount the tree while pumps are still legal, then
  // elapse fake time so drift's deferred stream-cache timer (scheduled on
  // every watch unsubscribe) fires before the postTest pending-timer check.
  // Test-scoped tearDowns run before the postTest disposal and checks.
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox());
    await pumpSettle(tester);
  });
  await stack.setLanguage(language);
  await tester.pumpWidget(
    AlarmxApp(
      repository: stack.repository,
      coordinator: stack.coordinator,
      settings: stack.settings,
    ),
  );
  await pumpSettle(tester);
}

/// Pumps [HomeScreen] standalone in [language].
Future<void> pumpHome(
  WidgetTester tester,
  TestStack stack, {
  String language = AppLanguage.english,
  ValueChanged<String>? onLanguageChanged,
}) async {
  // Self-cleaning: unmount the tree while pumps are still legal, then
  // elapse fake time so drift's deferred stream-cache timer (scheduled on
  // every watch unsubscribe) fires before the postTest pending-timer check.
  // Test-scoped tearDowns run before the postTest disposal and checks.
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox());
    await pumpSettle(tester);
  });
  await tester.pumpWidget(
    MaterialApp(
      locale: Locale(language),
      supportedLocales: testLocales,
      localizationsDelegates: testDelegates,
      home: HomeScreen(
        controller: stack.controller,
        languageCode: language,
        onLanguageChanged: onLanguageChanged ?? (_) {},
      ),
    ),
  );
  await pumpSettle(tester);
}

/// Pumps [AlarmEditorScreen] standalone in [language].
///
/// The popped [AlarmUiResult] is not captured here; tests assert the save
/// outcome through the repository + fake scheduler state instead (result
/// mapping itself is covered by the controller tests).
Future<void> pumpEditor(
  WidgetTester tester,
  TestStack stack, {
  String language = AppLanguage.english,
  int? alarmId,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      locale: Locale(language),
      supportedLocales: testLocales,
      localizationsDelegates: testDelegates,
      home: alarmId == null
          ? AlarmEditorScreen.create(controller: stack.controller)
          : AlarmEditorScreen.edit(
              controller: stack.controller,
              alarmId: alarmId,
            ),
    ),
  );
  await pumpSettle(tester);
}
