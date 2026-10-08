import 'package:alarmx/core/l10n/app_strings.dart';
import 'package:alarmx/core/models/models.dart';
import 'package:alarmx/core/permissions/permission_bridge.dart';
import 'package:alarmx/features/missions/mission_config.dart';
import 'package:alarmx/features/missions/permissions/camera_permission.dart';
import 'package:alarmx/features/permission_center/permission_center_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/test_doubles.dart';

// PermissionCenterScreen tests: real in-memory stack (alarms + missions),
// scripted native bridge + camera gate. English unless stated.

Future<void> pumpCenter(
  WidgetTester tester,
  TestStack stack, {
  String language = AppLanguage.english,
  PermissionSystemBridge? bridge,
  CameraPermissionGate? cameraGate,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      locale: Locale(language),
      supportedLocales: testLocales,
      localizationsDelegates: testDelegates,
      home: PermissionCenterScreen(
        bridge: bridge ?? FakePermissionSystemBridge(),
        cameraGate: cameraGate ?? FakeCameraStatusGate(),
        alarms: stack.repository,
        missions: stack.missions,
      ),
    ),
  );
  await pumpSettle(tester);
}

void main() {
  late TestStack stack;
  final AppStrings en = AppStrings.forCode('en');
  final AppStrings ar = AppStrings.forCode('ar');

  setUp(() {
    stack = TestStack();
  });

  // Each test builds a fresh stack; finishWidgetTest closes it.

  Future<void> seedCameraAlarm() async {
    final int alarmId = await stack.insertAlarm(label: 'Camera alarm');
    await stack.missions.saveMissionsForAlarm(
      alarmId,
      <MissionDraft>[
        MissionDraft(
          type: MissionType.qr,
          config: const QrMissionConfig('CODE-1'),
        ),
      ],
    );
  }

  testWidgets('renders all seven items', (WidgetTester tester) async {
    await stack.insertAlarm(label: 'Work');
    await pumpCenter(tester, stack);

    expect(find.text(en.permissionCenterTitle), findsOneWidget);
    expect(find.text(en.permNotificationsTitle), findsOneWidget);
    expect(find.text(en.permExactAlarmTitle), findsOneWidget);
    expect(find.text(en.permFullScreenTitle), findsOneWidget);
    expect(find.text(en.permBatteryTitle), findsOneWidget);
    expect(find.text(en.permBootTitle), findsOneWidget);
    expect(find.text(en.permCameraTitle), findsOneWidget);
    expect(find.text(en.permAlarmsTitle), findsOneWidget);
    await finishWidgetTest(tester, stack);
  });

  testWidgets('arabic locale renders RTL labels',
      (WidgetTester tester) async {
    await pumpCenter(tester, stack, language: AppLanguage.arabic);

    expect(find.text(ar.permissionCenterTitle), findsOneWidget);
    expect(find.text(ar.permNotificationsTitle), findsOneWidget);
    expect(find.text(ar.reliabilityReliable), findsWidgets);
    final Directionality directionality =
        tester.widget(find.byType(Directionality).first);
    expect(directionality.textDirection, TextDirection.rtl);
    await finishWidgetTest(tester, stack);
  });

  testWidgets('all-ready state shows the ready overall',
      (WidgetTester tester) async {
    await stack.insertAlarm(label: 'Work');
    await pumpCenter(tester, stack);

    expect(find.text(en.reliabilityExplainReliable), findsOneWidget);
    // Six rows plus the overall title share the Ready wording.
    expect(find.text(en.permStateReady), findsNWidgets(7));
    expect(find.text('1'), findsOneWidget);
    await finishWidgetTest(tester, stack);
  });

  testWidgets('multiple problems show attention plus actions',
      (WidgetTester tester) async {
    await stack.insertAlarm(label: 'Work');
    final Map<String, Object?> denied = fakeGrantedSnapshot();
    denied['notificationsEnabled'] = false;
    denied['canScheduleExactAlarms'] = false;
    denied['batteryExempt'] = false;
    denied['bootReceiverEnabled'] = false;
    await pumpCenter(
      tester,
      stack,
      bridge: FakePermissionSystemBridge(snapshot: denied),
      cameraGate: FakeCameraStatusGate(CameraPermissionOutcome.denied),
    );

    expect(find.text(en.reliabilityAttention), findsOneWidget);
    expect(find.text(en.reliabilityExplainAttention), findsOneWidget);
    expect(find.text(en.permStateDenied), findsNWidgets(2));
    expect(find.text(en.permStateNotExempt), findsOneWidget);
    expect(find.text(en.permStateUnavailable), findsOneWidget);
    expect(find.text(en.permStateNotRequired), findsOneWidget);
    expect(
      find.byKey(const Key('permission_action_notifications')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('permission_action_exactAlarm')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('permission_action_battery')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('permission_action_boot')), findsNothing);
    expect(find.byKey(const Key('permission_action_camera')), findsNothing);
    await finishWidgetTest(tester, stack);
  });

  testWidgets('recommended-only battery issue is mostly ready',
      (WidgetTester tester) async {
    await stack.insertAlarm(label: 'Work');
    final Map<String, Object?> active = fakeGrantedSnapshot();
    active['batteryExempt'] = false;
    await pumpCenter(
      tester,
      stack,
      bridge: FakePermissionSystemBridge(snapshot: active),
    );

    expect(find.text(en.reliabilityMostly), findsOneWidget);
    expect(find.text(en.permStateNotExempt), findsOneWidget);
    expect(find.text(en.permTagRecommended), findsOneWidget);
    await finishWidgetTest(tester, stack);
  });

  testWidgets('denied camera without a camera mission is not required',
      (WidgetTester tester) async {
    await stack.insertAlarm(label: 'Work');
    await pumpCenter(
      tester,
      stack,
      cameraGate: FakeCameraStatusGate(CameraPermissionOutcome.denied),
    );

    expect(find.text(en.permStateNotRequired), findsOneWidget);
    expect(find.text(en.reliabilityReliable), findsWidgets);
    expect(find.byKey(const Key('permission_action_camera')), findsNothing);
    await finishWidgetTest(tester, stack);
  });

  testWidgets('restricted camera with a camera mission offers app settings',
      (WidgetTester tester) async {
    await seedCameraAlarm();
    await pumpCenter(
      tester,
      stack,
      cameraGate:
          FakeCameraStatusGate(CameraPermissionOutcome.permanentlyDenied),
    );

    expect(find.text(en.permStateRestricted), findsOneWidget);
    expect(find.text(en.reliabilityMostly), findsOneWidget);
    expect(
      find.byKey(const Key('permission_action_camera')),
      findsOneWidget,
    );
    await finishWidgetTest(tester, stack);
  });

  testWidgets('not-applicable capabilities show no action',
      (WidgetTester tester) async {
    await stack.insertAlarm(label: 'Work');
    await pumpCenter(
      tester,
      stack,
      bridge: FakePermissionSystemBridge(
        snapshot: fakeGrantedSnapshot(sdkInt: 30),
      ),
    );

    expect(find.text(en.permStateNotApplicable), findsNWidgets(2));
    expect(
      find.byKey(const Key('permission_action_exactAlarm')),
      findsNothing,
    );
    expect(find.byKey(const Key('permission_action_fullScreen')), findsNothing);
    expect(
      find.byKey(const Key('permission_action_notifications')),
      findsOneWidget,
    );
    await finishWidgetTest(tester, stack);
  });

  testWidgets('tapping an action calls the bridge',
      (WidgetTester tester) async {
    await stack.insertAlarm(label: 'Work');
    final FakePermissionSystemBridge bridge = FakePermissionSystemBridge();
    await pumpCenter(tester, stack, bridge: bridge);

    await tester.tap(find.byKey(const Key('permission_action_battery')));
    await pumpSettle(tester);

    expect(bridge.opened, <PermissionSettingsTarget>[
      PermissionSettingsTarget.battery,
    ]);
    expect(find.text(en.permissionCenterActionFailed), findsNothing);
    await finishWidgetTest(tester, stack);
  });

  testWidgets('failed settings actions report honestly',
      (WidgetTester tester) async {
    await stack.insertAlarm(label: 'Work');
    final FakePermissionSystemBridge bridge = FakePermissionSystemBridge()
      ..settingsResult = false;
    await pumpCenter(tester, stack, bridge: bridge);

    await tester.tap(find.byKey(const Key('permission_action_battery')));
    await pumpSettle(tester);

    expect(find.text(en.permissionCenterActionFailed), findsOneWidget);
    await finishWidgetTest(tester, stack);
  });

  testWidgets('resume refreshes the state', (WidgetTester tester) async {
    await stack.insertAlarm(label: 'Work');
    final FakePermissionSystemBridge bridge = FakePermissionSystemBridge();
    await pumpCenter(tester, stack, bridge: bridge);
    expect(find.text(en.reliabilityExplainReliable), findsOneWidget);
    final int reads = bridge.reads;

    final Map<String, Object?> denied = fakeGrantedSnapshot();
    denied['canScheduleExactAlarms'] = false;
    bridge.snapshot = denied;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await pumpSettle(tester);

    expect(bridge.reads, greaterThan(reads));
    expect(find.text(en.reliabilityAttention), findsOneWidget);
    await finishWidgetTest(tester, stack);
  });

  testWidgets('read failure shows the error state with retry',
      (WidgetTester tester) async {
    final FakePermissionSystemBridge bridge = FakePermissionSystemBridge()
      ..failReads = true;
    await pumpCenter(tester, stack, bridge: bridge);

    expect(find.text(en.permissionCenterLoadFailed), findsOneWidget);
    expect(find.byKey(const Key('permission_center_retry')), findsOneWidget);

    bridge.failReads = false;
    await tester.tap(find.byKey(const Key('permission_center_retry')));
    await pumpSettle(tester);

    expect(find.text(en.permissionCenterLoadFailed), findsNothing);
    expect(find.text(en.permNotificationsTitle), findsOneWidget);
    await finishWidgetTest(tester, stack);
  });

  testWidgets('loading state shows a spinner', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        supportedLocales: testLocales,
        localizationsDelegates: testDelegates,
        home: PermissionCenterScreen(
          bridge: FakePermissionSystemBridge(),
          cameraGate: FakeCameraStatusGate(),
          alarms: stack.repository,
          missions: stack.missions,
        ),
      ),
    );
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await pumpSettle(tester);
    await finishWidgetTest(tester, stack);
  });

  testWidgets('no enabled alarms demotes findings and shows none',
      (WidgetTester tester) async {
    final Map<String, Object?> denied = fakeGrantedSnapshot();
    denied['notificationsEnabled'] = false;
    denied['canScheduleExactAlarms'] = false;
    await pumpCenter(
      tester,
      stack,
      bridge: FakePermissionSystemBridge(snapshot: denied),
    );

    expect(find.text(en.reliabilityMostly), findsOneWidget);
    expect(find.text(en.permAlarmsNone), findsOneWidget);
    expect(find.text(en.permStateDenied), findsNWidgets(2));
    await finishWidgetTest(tester, stack);
  });

  testWidgets('status icons carry semantic labels',
      (WidgetTester tester) async {
    final SemanticsHandle semantics = tester.ensureSemantics();
    await stack.insertAlarm(label: 'Work');
    await pumpCenter(tester, stack);

    expect(find.bySemanticsLabel(en.reliabilityReliable), findsWidgets);
    expect(find.bySemanticsLabel(en.permStateReady), findsWidgets);
    semantics.dispose();
    await finishWidgetTest(tester, stack);
  });

  testWidgets('home reliability button opens the center',
      (WidgetTester tester) async {
    await stack.insertAlarm(label: 'Work');
    await pumpHome(tester, stack);

    expect(find.byTooltip(en.reliabilityHomeReady), findsOneWidget);
    await tester.tap(find.byKey(const Key('home_reliability_button')));
    await pumpSettle(tester);

    expect(find.text(en.permissionCenterTitle), findsOneWidget);
    await finishWidgetTest(tester, stack);
  });

  testWidgets('home indicator reflects attention state',
      (WidgetTester tester) async {
    await stack.insertAlarm(label: 'Work');
    final Map<String, Object?> denied = fakeGrantedSnapshot();
    denied['canScheduleExactAlarms'] = false;
    await pumpHome(
      tester,
      stack,
      permissionBridge: FakePermissionSystemBridge(snapshot: denied),
    );

    expect(find.byTooltip(en.reliabilityHomeAttention), findsOneWidget);
    await finishWidgetTest(tester, stack);
  });
}
