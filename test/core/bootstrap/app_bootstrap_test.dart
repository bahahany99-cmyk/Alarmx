import 'dart:io';

import 'package:alarmx/core/bootstrap/app_bootstrap.dart';
import 'package:alarmx/core/database/database.dart';
import 'package:alarmx/core/models/models.dart';
import 'package:alarmx/core/repositories/alarm_repository.dart';
import 'package:alarmx/core/scheduling/alarm_schedule_result.dart';
import 'package:alarmx/core/scheduling/boot_reconciliation.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

// End-to-end tests for the production bootstrap wiring: a real file
// database in a temp dir (path_provider channel mocked) plus the real
// channel scheduler (scheduler channel mocked) prove that app launch and
// the headless entrypoint reconcile through the production objects.

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const MethodChannel schedulerChannel =
      MethodChannel('com.alarmx.app.alarmx/alarm_scheduler');
  const MethodChannel pathProviderChannel =
      MethodChannel('plugins.flutter.io/path_provider');
  final List<MethodCall> schedulerCalls = <MethodCall>[];
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('alarmx_bootstrap_');
    schedulerCalls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathProviderChannel,
            (MethodCall call) async {
      if (call.method == 'getApplicationDocumentsDirectory') {
        return tempDir.path;
      }
      return null;
    });
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(schedulerChannel, (MethodCall call) async {
      schedulerCalls.add(call);
      if (call.method == 'canScheduleExactAlarms') {
        return true;
      }
      return null;
    });
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathProviderChannel, null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(schedulerChannel, null);
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  Future<void> seedDailyAlarm() async {
    final AppDatabase db = AppDatabase();
    try {
      await DriftAlarmRepository(db.alarmDao).createAlarm(
        AlarmsCompanion(
          hour: const Value<int>(7),
          minute: const Value<int>(30),
          repeatType: Value(RepeatType.daily.dbValue),
        ),
      );
    } finally {
      await db.close();
    }
  }

  test('app-start bootstrap schedules a seeded alarm end to end', () async {
    await seedDailyAlarm();

    final ReconciliationReport report = await runProductionReconciliation(
      now: DateTime(2026, 10, 5, 10, 0),
    );

    expect(report.processed, 1);
    expect(report.scheduled, 1);
    expect(report.failed, 0);
    final MethodCall schedule = schedulerCalls.firstWhere(
      (MethodCall call) => call.method == 'scheduleExactAlarm',
    );
    final Map<String, Object?> args =
        Map<String, Object?>.from(schedule.arguments);
    expect(args['alarmId'], 1);
    expect(
      args['triggerAtMillis'],
      DateTime(2026, 10, 6, 7, 30).millisecondsSinceEpoch,
    );
    expect(args.containsKey('label'), isTrue);
    final AppDatabase check = AppDatabase();
    try {
      final Alarm? alarm =
          await DriftAlarmRepository(check.alarmDao).getAlarmById(1);
      expect(alarm!.nextTriggerAt, DateTime(2026, 10, 6, 7, 30));
    } finally {
      await check.close();
    }
  });

  test('headless entrypoint reconciles and completes the handshake', () async {
    await seedDailyAlarm();

    // Live reference time: a daily alarm is always schedulable, so the
    // outcome is deterministic without pinning the clock.
    await reconcileAfterBoot();

    final MethodCall complete = schedulerCalls.firstWhere(
      (MethodCall call) => call.method == 'onReconcileComplete',
    );
    final Map<String, Object?> payload =
        Map<String, Object?>.from(complete.arguments);
    expect(payload['ok'], isTrue);
    expect(payload['processed'], 1);
    expect(payload['scheduled'], 1);
    expect(payload['failed'], 0);
  });
}
