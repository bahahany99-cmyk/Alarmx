// TEMPORARY: manual native pipeline test screen. Will be replaced by the real home screen later.
import 'package:alarmx/core/alarms/native_alarm_scheduler_impl.dart';
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
            const SizedBox(height: 16),
            Text(_status),
          ],
        ),
      ),
    );
  }
}
