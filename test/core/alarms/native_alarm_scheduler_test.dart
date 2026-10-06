import 'package:alarmx/core/alarms/alarm_fire_config.dart';
import 'package:alarmx/core/alarms/native_alarm_scheduler_impl.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

// Contract tests for the MethodChannel argument shapes: what Dart sends must
// match what MainActivity.kt parses. A mocked binary messenger records the
// calls; no device or platform views are involved.

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const MethodChannel channel =
      MethodChannel('com.alarmx.app.alarmx/alarm_scheduler');
  final List<MethodCall> calls = <MethodCall>[];
  const NativeAlarmSchedulerImpl scheduler = NativeAlarmSchedulerImpl();

  setUp(() {
    calls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall call) async {
      calls.add(call);
      return null;
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('legacy schedule sends exactly the two-key map', () async {
    final DateTime trigger = DateTime(2026, 10, 6, 7, 30);

    await scheduler.scheduleExactAlarm(alarmId: 7, triggerAt: trigger);

    final MethodCall call = calls.single;
    expect(call.method, 'scheduleExactAlarm');
    expect(call.arguments, <String, Object?>{
      'alarmId': 7,
      'triggerAtMillis': trigger.millisecondsSinceEpoch,
    });
  });

  test('persisted schedule sends label and vibration flag', () async {
    final DateTime trigger = DateTime(2026, 10, 6, 7, 30);

    await scheduler.scheduleExactAlarm(
      alarmId: 3,
      triggerAt: trigger,
      fireConfig: const AlarmFireConfig(
        label: 'Gym',
        vibrationEnabled: false,
      ),
    );

    final MethodCall call = calls.single;
    expect(call.method, 'scheduleExactAlarm');
    expect(call.arguments, <String, Object?>{
      'alarmId': 3,
      'triggerAtMillis': trigger.millisecondsSinceEpoch,
      'label': 'Gym',
      'vibrationEnabled': false,
    });
  });

  test('null label is sent as an explicit null entry', () async {
    await scheduler.scheduleExactAlarm(
      alarmId: 3,
      triggerAt: DateTime(2026, 10, 6, 7, 30),
      fireConfig: const AlarmFireConfig(),
    );

    final Map<String, Object?> args =
        Map<String, Object?>.from(calls.single.arguments);
    expect(args.containsKey('label'), isTrue);
    expect(args['label'], isNull);
    expect(args['vibrationEnabled'], isTrue);
  });

  test('cancel sends the alarm id', () async {
    await scheduler.cancelAlarm(alarmId: 9);

    final MethodCall call = calls.single;
    expect(call.method, 'cancelAlarm');
    expect(call.arguments, <String, Object?>{'alarmId': 9});
  });

  test('permission check returns the native answer', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall call) async {
      calls.add(call);
      return true;
    });

    expect(await scheduler.canScheduleExactAlarms(), isTrue);
    expect(calls.single.method, 'canScheduleExactAlarms');
  });

  test('permission check defaults to false on null', () async {
    expect(await scheduler.canScheduleExactAlarms(), isFalse);
    expect(calls.single.method, 'canScheduleExactAlarms');
  });
}
