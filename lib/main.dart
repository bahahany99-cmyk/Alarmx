// TEMPORARY: manual native pipeline test screen. Will be replaced by the real home screen later.
import 'package:alarmx/core/alarms/native_alarm_events.dart';
import 'package:alarmx/core/alarms/native_alarm_scheduler_impl.dart';
import 'package:alarmx/core/database/database.dart';
import 'package:alarmx/core/models/models.dart';
import 'package:alarmx/core/repositories/alarm_repository.dart';
import 'package:alarmx/core/scheduling/alarm_schedule_result.dart';
import 'package:alarmx/core/scheduling/alarm_scheduling_coordinator.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AlarmX - Native Pipeline Test',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: const NativePipelineTestScreen(),
    );
  }
}

class NativePipelineTestScreen extends StatefulWidget {
  const NativePipelineTestScreen({super.key});

  @override
  State<NativePipelineTestScreen> createState() =>
      _NativePipelineTestScreenState();
}

class _NativePipelineTestScreenState extends State<NativePipelineTestScreen> {
  String _status = 'No action yet';
  int? _persistedTestAlarmId;

  // TEMP: single database + coordinator for the persisted-alarm test
  // buttons below. Created lazily on first press, so plain widget tests
  // that never press them are unaffected. The real app will own the
  // database lifecycle properly.
  late final AppDatabase _tempDb = AppDatabase();
  late final AlarmRepository _tempRepo =
      DriftAlarmRepository(_tempDb.alarmDao);
  late final AlarmSchedulingCoordinator _tempCoordinator =
      AlarmSchedulingCoordinator(
    repository: _tempRepo,
    scheduler: const NativeAlarmSchedulerImpl(),
  );

  // TEMP: listens for native post-fire stops (placeholder for real app
  // wiring, which will attach this in the app shell instead).
  final NativeAlarmEvents _tempEvents = NativeAlarmEvents();

  @override
  void initState() {
    super.initState();
    _tempEvents.onAlarmStopped = _handlePersistedAlarmStopped;
    _tempEvents.attach();
  }

  @override
  void dispose() {
    _tempEvents.detach();
    super.dispose();
  }

  Future<void> _scheduleTestAlarm() async {
    try {
      final NativeAlarmSchedulerImpl scheduler =
          const NativeAlarmSchedulerImpl();
      final DateTime triggerAt =
          DateTime.now().add(const Duration(seconds: 10));
      await scheduler.scheduleExactAlarm(alarmId: 1, triggerAt: triggerAt);
      if (!mounted) {
        return;
      }
      setState(() {
        _status = 'Scheduled alarm for $triggerAt';
      });
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _status = 'Schedule failed: $e';
      });
    }
  }

  Future<void> _cancelTestAlarm() async {
    try {
      final NativeAlarmSchedulerImpl scheduler =
          const NativeAlarmSchedulerImpl();
      await scheduler.cancelAlarm(alarmId: 1);
      if (!mounted) {
        return;
      }
      setState(() {
        _status = 'Cancelled alarm 1';
      });
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _status = 'Cancel failed: $e';
      });
    }
  }

  Future<void> _checkPermission() async {
    try {
      final NativeAlarmSchedulerImpl scheduler =
          const NativeAlarmSchedulerImpl();
      final bool canSchedule = await scheduler.canScheduleExactAlarms();
      if (!mounted) {
        return;
      }
      setState(() {
        _status = 'canScheduleExactAlarms: $canSchedule';
      });
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _status = 'Permission check failed: $e';
      });
    }
  }

  // TEMP (Phase 2.3 device-test hook): creates a real database alarm ~2
  // minutes out and schedules it through the coordinator, exercising the
  // full persisted path (Drift -> coordinator -> native extras/ledger ->
  // AlarmReceiver -> service ring). Each press creates a new row; use the
  // cancel button to remove the last one.
  Future<void> _schedulePersistedTestAlarm() async {
    try {
      final DateTime target = DateTime.now().add(const Duration(minutes: 2));
      final int id = await _tempRepo.createAlarm(
        AlarmsCompanion(
          hour: Value(target.hour),
          minute: Value(target.minute),
          label: const Value<String?>('Persisted test'),
          repeatType: Value(RepeatType.once.dbValue),
          onceDate: Value(DateTime(target.year, target.month, target.day)),
        ),
      );
      final AlarmScheduleResult result =
          await _tempCoordinator.scheduleAlarm(id);
      _persistedTestAlarmId = id;
      if (!mounted) {
        return;
      }
      final String outcome = switch (result) {
        AlarmScheduled(:final triggerAt) =>
          'Scheduled persisted alarm $id for $triggerAt',
        AlarmNotSchedulable(:final reason) => 'Not schedulable: $reason',
        AlarmDisabled() => 'Unexpected: alarm came back disabled',
        AlarmPermissionMissing() => 'Exact-alarm permission missing',
        AlarmScheduleFailed(:final error) => 'Schedule failed: $error',
      };
      setState(() {
        _status = outcome;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _status = 'Persisted test failed: $e';
      });
    }
  }

  // TEMP (Phase 2.4): routes a native post-fire stop to the coordinator so
  // recurring alarms chain while the app is open, and reports the outcome.
  Future<void> _handlePersistedAlarmStopped(
    int alarmId,
    DateTime firedTriggerAt,
  ) async {
    try {
      final AlarmScheduleResult result =
          await _tempCoordinator.rescheduleAfterFire(
        alarmId: alarmId,
        firedTriggerAt: firedTriggerAt,
      );
      if (!mounted) {
        return;
      }
      final String outcome = switch (result) {
        AlarmScheduled(:final triggerAt) =>
          'Post-fire: rescheduled alarm $alarmId for $triggerAt',
        AlarmNotSchedulable(:final reason) =>
          'Post-fire: no further schedule ($reason)',
        AlarmDisabled() =>
          'Post-fire: alarm $alarmId disabled, not rescheduled',
        AlarmPermissionMissing() => 'Post-fire: exact-alarm permission missing',
        AlarmScheduleFailed(:final error) => 'Post-fire failed: $error',
      };
      setState(() {
        _status = outcome;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _status = 'Post-fire failed: $e';
      });
    }
  }

  // TEMP: cancels the last persisted test alarm and deletes its row.
  Future<void> _cancelPersistedTestAlarm() async {
    try {
      final int? id = _persistedTestAlarmId;
      if (id == null) {
        setState(() {
          _status = 'No persisted test alarm to cancel';
        });
        return;
      }
      await _tempCoordinator.cancelAlarm(id);
      await _tempRepo.deleteAlarm(id);
      _persistedTestAlarmId = null;
      if (!mounted) {
        return;
      }
      setState(() {
        _status = 'Cancelled and deleted persisted test alarm $id';
      });
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _status = 'Persisted cancel failed: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AlarmX - Native Pipeline Test'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: _scheduleTestAlarm,
              child: const Text('Schedule test alarm in 10 seconds'),
            ),
            ElevatedButton(
              onPressed: _cancelTestAlarm,
              child: const Text('Cancel test alarm'),
            ),
            ElevatedButton(
              onPressed: _checkPermission,
              child: const Text('Check exact alarm permission'),
            ),
            ElevatedButton(
              onPressed: _schedulePersistedTestAlarm,
              child: const Text('TEMP: Persisted alarm (~2 min)'),
            ),
            ElevatedButton(
              onPressed: _cancelPersistedTestAlarm,
              child: const Text('TEMP: Cancel persisted test'),
            ),
            const SizedBox(height: 16),
            Text(_status),
          ],
        ),
      ),
    );
  }
}
