import 'package:alarmx/core/database/database.dart';
import 'package:alarmx/core/l10n/app_strings.dart';
import 'package:alarmx/core/models/models.dart';
import 'package:alarmx/features/missions/mission_config.dart';
import 'package:alarmx/features/ringing_alarm/ringing_alarm_bridge.dart';
import 'package:alarmx/features/ringing_alarm/ringing_launch.dart';
import 'package:alarmx/features/ringing_alarm/ringing_mission_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/test_doubles.dart';

// Ringing flow tests (Phase 5): strict stop gate, snooze deferral,
// Emergency Exit (hold + PIN), and retry paths. Real in-memory stack,
// English locale.

class FlowBridge implements RingingAlarmBridge {
  FlowBridge({this.launch});

  RingingLaunch? launch;
  final List<int> stops = <int>[];
  final List<Object> stopErrors = <Object>[];

  @override
  Future<RingingLaunch?> consumeRingingLaunch() async => launch;

  @override
  Future<void> stopRingingAlarm(int alarmId) async {
    if (stopErrors.isNotEmpty) {
      throw stopErrors.removeAt(0);
    }
    stops.add(alarmId);
  }
}

Future<void> pumpFlow(
  WidgetTester tester,
  TestStack stack, {
  required int alarmId,
  required FlowBridge bridge,
  required VoidCallback onFinished,
  int? triggerAtMillis,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale(AppLanguage.english),
      supportedLocales: testLocales,
      localizationsDelegates: testDelegates,
      home: RingingMissionScreen(
        launch: RingingLaunch(
          alarmId: alarmId,
          label: 'Morning',
          triggerAtMillis: triggerAtMillis,
        ),
        alarms: stack.repository,
        missionService: stack.missions,
        history: stack.history,
        coordinator: stack.coordinator,
        pinService: stack.pinService,
        bridge: bridge,
        onFinished: onFinished,
      ),
    ),
  );
  await pumpSettle(tester);
}

Future<void> solveTyping(WidgetTester tester, String text) async {
  await tester.enterText(
    find.byKey(const Key('typing_answer_field')),
    text,
  );
  await tester.tap(find.byKey(const Key('typing_check_button')));
  await pumpSettle(tester);
}

MissionDraft typing(String text, {bool required = true}) {
  return MissionDraft(
    type: MissionType.typing,
    config: TypingMissionConfig(text),
    required: required,
  );
}

/// Seeds an alarm with Phase 5 ring options; returns its id.
Future<int> seedRingingAlarm(
  TestStack stack, {
  bool strict = false,
  bool snoozeEnabled = true,
  int snoozeMinutes = 10,
}) async {
  final int id = await stack.insertAlarm(hour: 7, minute: 30);
  final Alarm? alarm = await stack.repository.getAlarmById(id);
  await stack.repository.updateAlarm(
    alarm!.copyWith(
      strictMode: strict,
      snoozeEnabled: snoozeEnabled,
      snoozeMinutes: snoozeMinutes,
    ),
  );
  return id;
}

/// Schedules [id] through the coordinator (the production path that
/// persists `nextTriggerAt`) and returns the stored trigger token.
Future<DateTime> scheduleToken(TestStack stack, int id) async {
  await stack.coordinator.scheduleAlarm(id, now: DateTime.now());
  final Alarm? alarm = await stack.repository.getAlarmById(id);
  stack.scheduler.scheduledTriggers.clear();
  return alarm!.nextTriggerAt!;
}

void main() {
  final AppStrings en = AppStrings.forCode(AppLanguage.english);
  late TestStack stack;

  setUp(() {
    stack = TestStack();
  });

  // Each test builds a fresh stack; finishWidgetTest closes it.

  bool stopEnabled(WidgetTester tester) {
    final FilledButton button = tester.widget<FilledButton>(
      find.byKey(const Key('ringing_stop_button')),
    );
    return button.onPressed != null;
  }

  group('strict stop gate', () {
    testWidgets('non-strict stop works with pending missions',
        (WidgetTester tester) async {
      final int alarmId = await seedRingingAlarm(stack);
      await stack.missions.saveMissionsForAlarm(alarmId, <MissionDraft>[
        typing('wake up'),
      ]);
      final FlowBridge bridge = FlowBridge();
      int finished = 0;
      await pumpFlow(
        tester,
        stack,
        alarmId: alarmId,
        bridge: bridge,
        onFinished: () {
          finished++;
        },
      );

      expect(stopEnabled(tester), isTrue);
      await tester.ensureVisible(
        find.byKey(const Key('ringing_stop_button')),
      );
      await pumpSettle(tester);
      await tester.tap(find.byKey(const Key('ringing_stop_button')));
      await pumpSettle(tester);
      expect(bridge.stops, <int>[alarmId]);
      expect(finished, 1);
      await finishWidgetTest(tester, stack);
    });

    testWidgets('strict locks stop until missions complete',
        (WidgetTester tester) async {
      final int alarmId = await seedRingingAlarm(stack, strict: true);
      await stack.missions.saveMissionsForAlarm(alarmId, <MissionDraft>[
        typing('wake up'),
      ]);
      final FlowBridge bridge = FlowBridge();
      int finished = 0;
      await pumpFlow(
        tester,
        stack,
        alarmId: alarmId,
        bridge: bridge,
        onFinished: () {
          finished++;
        },
      );

      expect(stopEnabled(tester), isFalse);
      expect(find.text(en.ringingStrictLocked), findsOneWidget);
      await solveTyping(tester, 'wake up');
      expect(bridge.stops, <int>[alarmId]);
      expect(finished, 1);
      await finishWidgetTest(tester, stack);
    });

    testWidgets('strict with zero missions stays stoppable',
        (WidgetTester tester) async {
      final int alarmId = await seedRingingAlarm(stack, strict: true);
      final FlowBridge bridge = FlowBridge();
      int finished = 0;
      await pumpFlow(
        tester,
        stack,
        alarmId: alarmId,
        bridge: bridge,
        onFinished: () {
          finished++;
        },
      );

      expect(stopEnabled(tester), isTrue);
      await tester.tap(find.byKey(const Key('ringing_stop_button')));
      await pumpSettle(tester);
      expect(bridge.stops, <int>[alarmId]);
      expect(finished, 1);
      await finishWidgetTest(tester, stack);
    });

    testWidgets('recreated screen cannot bypass the strict gate',
        (WidgetTester tester) async {
      final int alarmId = await seedRingingAlarm(stack, strict: true);
      await stack.missions.saveMissionsForAlarm(alarmId, <MissionDraft>[
        typing('first'),
        typing('second'),
      ]);
      final FlowBridge bridge = FlowBridge();
      int finished = 0;
      Future<void> pump() => pumpFlow(
            tester,
            stack,
            alarmId: alarmId,
            bridge: bridge,
            onFinished: () {
              finished++;
            },
          );
      await pump();

      await solveTyping(tester, 'first');
      expect(bridge.stops, isEmpty);
      // Recreate the screen mid-ring: a fresh session is incomplete by
      // construction, so the gate still holds.
      await pump();
      expect(stopEnabled(tester), isFalse);
      expect(find.text(en.ringingStrictLocked), findsOneWidget);
      expect(bridge.stops, isEmpty);
      expect(finished, 0);
      await finishWidgetTest(tester, stack);
    });
  });

  group('snooze', () {
    testWidgets('snooze defers through the coordinator and records',
        (WidgetTester tester) async {
      final int alarmId = await seedRingingAlarm(stack);
      final DateTime token = await scheduleToken(stack, alarmId);
      final FlowBridge bridge = FlowBridge();
      int finished = 0;
      await pumpFlow(
        tester,
        stack,
        alarmId: alarmId,
        bridge: bridge,
        onFinished: () {
          finished++;
        },
        triggerAtMillis: token.millisecondsSinceEpoch,
      );

      expect(
        find.byKey(const Key('ringing_snooze_button')),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const Key('ringing_snooze_button')));
      await pumpSettle(tester);

      expect(finished, 1);
      expect(bridge.stops, <int>[alarmId]);
      expect(find.text(en.ringingSnoozed), findsOneWidget);
      final DateTime target = stack.scheduler.scheduledTriggers.single;
      expect(
        target.isAfter(DateTime.now().add(const Duration(minutes: 9))),
        isTrue,
      );
      expect(
        target.isBefore(DateTime.now().add(const Duration(minutes: 11))),
        isTrue,
      );
      final AlarmHistoryData episode =
          (await stack.history.getHistoryForAlarm(alarmId)).single;
      expect(episode.snoozeCount, 1);
      // Drift stores DateTimes at whole-second precision; compare the
      // pending target accordingly (both sides derive from it anyway).
      expect(
        episode.stoppedAt?.millisecondsSinceEpoch,
        target.millisecondsSinceEpoch ~/ 1000 * 1000,
      );
      await finishWidgetTest(tester, stack);
    });

    testWidgets('snooze hidden without a schedule token',
        (WidgetTester tester) async {
      final int alarmId = await seedRingingAlarm(stack);
      final FlowBridge bridge = FlowBridge();
      await pumpFlow(
        tester,
        stack,
        alarmId: alarmId,
        bridge: bridge,
        onFinished: () {},
      );

      expect(
        find.byKey(const Key('ringing_snooze_button')),
        findsNothing,
      );
      await finishWidgetTest(tester, stack);
    });

    testWidgets('snooze hidden when disabled', (WidgetTester tester) async {
      final int alarmId = await seedRingingAlarm(
        stack,
        snoozeEnabled: false,
      );
      final DateTime token = await scheduleToken(stack, alarmId);
      final FlowBridge bridge = FlowBridge();
      await pumpFlow(
        tester,
        stack,
        alarmId: alarmId,
        bridge: bridge,
        onFinished: () {},
        triggerAtMillis: token.millisecondsSinceEpoch,
      );

      expect(
        find.byKey(const Key('ringing_snooze_button')),
        findsNothing,
      );
      await finishWidgetTest(tester, stack);
    });

    testWidgets('snooze stop-leg retry never schedules twice',
        (WidgetTester tester) async {
      final int alarmId = await seedRingingAlarm(stack);
      final DateTime token = await scheduleToken(stack, alarmId);
      final FlowBridge bridge = FlowBridge()
        ..stopErrors.add(StateError('native down'));
      int finished = 0;
      await pumpFlow(
        tester,
        stack,
        alarmId: alarmId,
        bridge: bridge,
        onFinished: () {
          finished++;
        },
        triggerAtMillis: token.millisecondsSinceEpoch,
      );

      await tester.tap(find.byKey(const Key('ringing_snooze_button')));
      await pumpSettle(tester);
      expect(find.text(en.ringingStopFailed), findsOneWidget);
      expect(stack.scheduler.scheduledTriggers.length, 1);
      expect(finished, 0);

      await tester.tap(find.byKey(const Key('ringing_retry_button')));
      await pumpSettle(tester);
      expect(stack.scheduler.scheduledTriggers.length, 1);
      expect(bridge.stops, <int>[alarmId]);
      expect(finished, 1);
      final AlarmHistoryData episode =
          (await stack.history.getHistoryForAlarm(alarmId)).single;
      expect(episode.snoozeCount, 1);
      await finishWidgetTest(tester, stack);
    });
  });

  group('emergency exit', () {
    Future<void> scrollToHold(WidgetTester tester) async {
      await tester.ensureVisible(
        find.byKey(const Key('emergency_hold_button')),
      );
      await pumpSettle(tester);
    }

    testWidgets('completed hold stops and preserves the alarm',
        (WidgetTester tester) async {
      final int alarmId = await seedRingingAlarm(stack, strict: true);
      await stack.missions.saveMissionsForAlarm(alarmId, <MissionDraft>[
        typing('never solved'),
      ]);
      final FlowBridge bridge = FlowBridge();
      int finished = 0;
      await pumpFlow(
        tester,
        stack,
        alarmId: alarmId,
        bridge: bridge,
        onFinished: () {
          finished++;
        },
      );
      await scrollToHold(tester);

      final TestGesture hold = await tester.startGesture(
        tester.getCenter(find.byKey(const Key('emergency_hold_button'))),
      );
      await tester.pump(const Duration(seconds: 11));
      await hold.up();
      await pumpSettle(tester);

      expect(bridge.stops, <int>[alarmId]);
      expect(finished, 1);
      expect(find.text(en.ringingEmergencyDone), findsOneWidget);
      final AlarmHistoryData episode =
          (await stack.history.getHistoryForAlarm(alarmId)).single;
      expect(episode.result, AlarmResult.emergencyStop.dbValue);
      final Alarm? alarm = await stack.repository.getAlarmById(alarmId);
      expect(alarm!.enabled, isTrue);
      expect(alarm.strictMode, isTrue);
      expect(alarm.hour, 7);
      expect(alarm.minute, 30);
      await finishWidgetTest(tester, stack);
    });

    testWidgets('hold released early cancels', (WidgetTester tester) async {
      final int alarmId = await seedRingingAlarm(stack, strict: true);
      final FlowBridge bridge = FlowBridge();
      int finished = 0;
      await pumpFlow(
        tester,
        stack,
        alarmId: alarmId,
        bridge: bridge,
        onFinished: () {
          finished++;
        },
      );
      await scrollToHold(tester);

      final TestGesture hold = await tester.startGesture(
        tester.getCenter(find.byKey(const Key('emergency_hold_button'))),
      );
      await tester.pump(const Duration(seconds: 2));
      await hold.up();
      await pumpSettle(tester);

      expect(bridge.stops, isEmpty);
      expect(finished, 0);
      expect(find.text(en.emergencyHold), findsOneWidget);
      await finishWidgetTest(tester, stack);
    });

    testWidgets('emergency PIN exits when enabled',
        (WidgetTester tester) async {
      await stack.pinService.setPin(pin: '1234', confirmation: '1234');
      final int alarmId = await seedRingingAlarm(stack, strict: true);
      final FlowBridge bridge = FlowBridge();
      int finished = 0;
      await pumpFlow(
        tester,
        stack,
        alarmId: alarmId,
        bridge: bridge,
        onFinished: () {
          finished++;
        },
      );
      await tester.ensureVisible(
        find.byKey(const Key('emergency_pin_button')),
      );
      await pumpSettle(tester);

      await tester.tap(find.byKey(const Key('emergency_pin_button')));
      await pumpSettle(tester);
      await tester.enterText(
        find.byKey(const Key('pin_prompt_field')),
        '1234',
      );
      await tester.tap(find.byKey(const Key('pin_prompt_confirm')));
      await pumpSettle(tester);

      expect(bridge.stops, <int>[alarmId]);
      expect(finished, 1);
      final AlarmHistoryData episode =
          (await stack.history.getHistoryForAlarm(alarmId)).single;
      expect(episode.result, AlarmResult.emergencyStop.dbValue);
      await finishWidgetTest(tester, stack);
    });

    testWidgets('emergency PIN hidden without a PIN',
        (WidgetTester tester) async {
      final int alarmId = await seedRingingAlarm(stack, strict: true);
      final FlowBridge bridge = FlowBridge();
      await pumpFlow(
        tester,
        stack,
        alarmId: alarmId,
        bridge: bridge,
        onFinished: () {},
      );
      await scrollToHold(tester);

      expect(
        find.byKey(const Key('emergency_pin_button')),
        findsNothing,
      );
      await finishWidgetTest(tester, stack);
    });
  });
}
