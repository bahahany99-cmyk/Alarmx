import 'package:alarmx/core/l10n/app_strings.dart';
import 'package:alarmx/core/permissions/permission_bridge.dart';
import 'package:alarmx/core/repositories/onboarding_repository.dart';
import 'package:alarmx/features/onboarding/notification_permission_gate.dart';
import 'package:alarmx/features/onboarding/onboarding_screen.dart';
import 'package:alarmx/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/test_doubles.dart';

// OnboardingScreen tests: scripted bridge + notification gate + completion
// store. English unless stated.

/// All-denied native snapshot map (boot stays granted: receivers ship
/// enabled on normal devices).
Map<String, Object?> fakeDeniedSnapshot() {
  final Map<String, Object?> snapshot = fakeGrantedSnapshot();
  snapshot['postNotificationsGranted'] = false;
  snapshot['canScheduleExactAlarms'] = false;
  snapshot['fullScreenIntentAllowed'] = false;
  snapshot['batteryExempt'] = false;
  return snapshot;
}

/// Bridge replaying a script of snapshots, one per read (last repeats).
class ScriptedSnapshotBridge implements PermissionSystemBridge {
  ScriptedSnapshotBridge(this.snapshots);

  final List<Map<String, Object?>> snapshots;
  final List<PermissionSettingsTarget> opened = <PermissionSettingsTarget>[];
  int reads = 0;

  @override
  Future<Map<String, Object?>> readSnapshot() async {
    final Map<String, Object?> snapshot = snapshots[
        reads < snapshots.length ? reads : snapshots.length - 1];
    reads++;
    return snapshot;
  }

  @override
  Future<bool> openSettings(PermissionSettingsTarget target) async {
    opened.add(target);
    return true;
  }
}

Future<void> pumpOnboarding(
  WidgetTester tester, {
  PermissionSystemBridge? bridge,
  NotificationPermissionGate? notificationGate,
  OnboardingRepository? onboarding,
  DateTime Function()? clock,
  VoidCallback? onFinished,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('en'),
      supportedLocales: testLocales,
      localizationsDelegates: testDelegates,
      home: OnboardingScreen(
        bridge: bridge ?? FakePermissionSystemBridge(),
        notificationGate: notificationGate ?? FakeNotificationGate(),
        onboarding: onboarding ?? FakeOnboardingRepository(),
        onFinished: onFinished ?? () {},
        clock: clock,
      ),
    ),
  );
  await pumpSettle(tester);
}

Future<void> tapPrimary(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('onboarding_primary')));
  await pumpSettle(tester);
}

Future<void> tapContinue(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('onboarding_continue')));
  await pumpSettle(tester);
}

void main() {
  late TestStack stack;
  final AppStrings en = AppStrings.forCode('en');

  setUp(() {
    stack = TestStack();
  });

  testWidgets('shows the notifications step first with rationale and action',
      (WidgetTester tester) async {
    await pumpOnboarding(
      tester,
      bridge: FakePermissionSystemBridge(snapshot: fakeDeniedSnapshot()),
    );

    expect(find.text(en.onboardingTitle), findsOneWidget);
    expect(find.text(en.onboardingNotificationsTitle), findsOneWidget);
    expect(find.text(en.onboardingNotificationsWhy), findsOneWidget);
    expect(find.text(en.onboardingNotificationsAction), findsOneWidget);
    expect(find.text(en.onboardingNotGranted), findsOneWidget);
    expect(find.byKey(const Key('onboarding_continue')), findsNothing);
    expect(find.byKey(const Key('onboarding_skip')), findsNothing);
    expect(find.byKey(const Key('onboarding_done')), findsNothing);
    await finishWidgetTest(tester, stack);
  });

  testWidgets('notifications dialog grant advances to the exact step',
      (WidgetTester tester) async {
    final ScriptedSnapshotBridge bridge = ScriptedSnapshotBridge(
      <Map<String, Object?>>[fakeDeniedSnapshot(), fakeGrantedSnapshot()],
    );
    final FakeNotificationGate gate = FakeNotificationGate(
      NotificationPermissionOutcome.granted,
    );
    await pumpOnboarding(tester, bridge: bridge, notificationGate: gate);

    await tapPrimary(tester);

    expect(gate.requests, 1);
    // Runtime dialog path: no Settings launch involved.
    expect(bridge.opened, isEmpty);
    expect(find.text(en.onboardingExactTitle), findsOneWidget);
    expect(find.text(en.onboardingNotificationsTitle), findsNothing);
    await finishWidgetTest(tester, stack);
  });

  testWidgets('denied notifications block advancement',
      (WidgetTester tester) async {
    final FakeNotificationGate gate = FakeNotificationGate(
      NotificationPermissionOutcome.denied,
    );
    await pumpOnboarding(
      tester,
      bridge: FakePermissionSystemBridge(snapshot: fakeDeniedSnapshot()),
      notificationGate: gate,
    );

    await tapPrimary(tester);

    expect(gate.requests, 1);
    expect(find.text(en.onboardingNotificationsTitle), findsOneWidget);
    expect(find.text(en.onboardingExactTitle), findsNothing);
    await finishWidgetTest(tester, stack);
  });

  testWidgets('permanently denied notifications fall back to settings',
      (WidgetTester tester) async {
    final FakePermissionSystemBridge bridge =
        FakePermissionSystemBridge(snapshot: fakeDeniedSnapshot());
    final FakeNotificationGate gate = FakeNotificationGate(
      NotificationPermissionOutcome.permanentlyDenied,
    );
    final DateTime now = DateTime(2026, 1, 1);
    await pumpOnboarding(
      tester,
      bridge: bridge,
      notificationGate: gate,
      clock: () => now,
    );

    await tapPrimary(tester);

    expect(gate.requests, 1);
    expect(
      bridge.opened,
      <PermissionSettingsTarget>[PermissionSettingsTarget.notifications],
    );
    // Still denied after the instant return: bounce recovery is offered.
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await pumpSettle(tester);
    expect(find.text(en.onboardingBounceNote), findsOneWidget);
    await finishWidgetTest(tester, stack);
  });

  testWidgets('not-applicable steps are skipped silently',
      (WidgetTester tester) async {
    await pumpOnboarding(
      tester,
      bridge: FakePermissionSystemBridge(
        snapshot: fakeGrantedSnapshot(sdkInt: 30),
      ),
    );

    // Notifications granted on arrival: Continue through; exact and
    // full-screen do not exist on this OS and never render.
    await tapContinue(tester);
    expect(find.text(en.onboardingExactTitle), findsNothing);
    expect(find.text(en.onboardingFullScreenTitle), findsNothing);
    expect(find.text(en.onboardingBootTitle), findsOneWidget);
    await finishWidgetTest(tester, stack);
  });

  testWidgets('boot denied shows info with no action',
      (WidgetTester tester) async {
    final Map<String, Object?> snapshot = fakeGrantedSnapshot();
    snapshot['bootReceiverEnabled'] = false;
    await pumpOnboarding(
      tester,
      bridge: FakePermissionSystemBridge(snapshot: snapshot),
    );

    await tapContinue(tester);
    await tapContinue(tester);
    await tapContinue(tester);

    expect(find.text(en.onboardingBootTitle), findsOneWidget);
    expect(find.text(en.onboardingNotGranted), findsOneWidget);
    expect(find.byKey(const Key('onboarding_primary')), findsNothing);
    expect(find.byKey(const Key('onboarding_continue')), findsNothing);
    expect(find.byKey(const Key('onboarding_skip')), findsNothing);
    await finishWidgetTest(tester, stack);
  });

  testWidgets('battery skip completes without grant',
      (WidgetTester tester) async {
    final Map<String, Object?> snapshot = fakeGrantedSnapshot();
    snapshot['batteryExempt'] = false;
    final FakeOnboardingRepository onboarding = FakeOnboardingRepository();
    bool finished = false;
    await pumpOnboarding(
      tester,
      bridge: FakePermissionSystemBridge(snapshot: snapshot),
      onboarding: onboarding,
      onFinished: () {
        finished = true;
      },
    );

    await tapContinue(tester);
    await tapContinue(tester);
    await tapContinue(tester);
    await tapContinue(tester);
    expect(find.text(en.onboardingBatteryTitle), findsOneWidget);
    expect(find.byKey(const Key('onboarding_skip')), findsOneWidget);

    await tester.tap(find.byKey(const Key('onboarding_skip')));
    await pumpSettle(tester);

    expect(find.text(en.onboardingCompleteTitle), findsOneWidget);
    expect(onboarding.completed, isTrue);

    await tester.tap(find.byKey(const Key('onboarding_done')));
    await pumpSettle(tester);
    expect(finished, isTrue);
    await finishWidgetTest(tester, stack);
  });

  testWidgets('bounce offers the app-info fallback',
      (WidgetTester tester) async {
    final Map<String, Object?> snapshot = fakeGrantedSnapshot();
    snapshot['canScheduleExactAlarms'] = false;
    snapshot['batteryExempt'] = false;
    final FakePermissionSystemBridge bridge =
        FakePermissionSystemBridge(snapshot: snapshot);
    final DateTime now = DateTime(2026, 1, 1);
    await pumpOnboarding(tester, bridge: bridge, clock: () => now);

    await tapContinue(tester);
    expect(find.text(en.onboardingExactTitle), findsOneWidget);
    await tapPrimary(tester);
    expect(
      bridge.opened,
      <PermissionSettingsTarget>[PermissionSettingsTarget.exactAlarm],
    );

    // Instant return while still denied: bounce recovery UI appears.
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await pumpSettle(tester);
    expect(find.text(en.onboardingBounceNote), findsOneWidget);
    expect(find.text(en.onboardingAppInfoAction), findsOneWidget);

    await tester.tap(find.text(en.onboardingAppInfoAction));
    await pumpSettle(tester);
    expect(
      bridge.opened,
      <PermissionSettingsTarget>[
        PermissionSettingsTarget.exactAlarm,
        PermissionSettingsTarget.appDetails,
      ],
    );
    await finishWidgetTest(tester, stack);
  });

  testWidgets('shell shows onboarding on first launch, home after completion',
      (WidgetTester tester) async {
    final OnboardingRepository onboarding =
        DriftOnboardingRepository(stack.db);
    // The shell renders the stored language (Arabic by default); switch to
    // English like pumpAlarmxApp does before asserting English strings.
    await stack.setLanguage('en');
    // Scripted platform: this test owns shell routing, not the native
    // channel (an unmocked MethodChannel never settles under pumpSettle).
    final FakePermissionSystemBridge bridge = FakePermissionSystemBridge();
    final FakeNotificationGate gate = FakeNotificationGate();
    Future<void> pumpShell() {
      return tester.pumpWidget(
        AlarmxApp(
          repository: stack.repository,
          coordinator: stack.coordinator,
          settings: stack.settings,
          missionService: stack.missions,
          history: stack.history,
          permissionBridge: bridge,
          notificationGate: gate,
          onboarding: onboarding,
        ),
      );
    }

    await pumpShell();
    await pumpSettle(tester);
    expect(find.text(en.onboardingTitle), findsOneWidget);
    expect(find.text(en.homeTitle), findsNothing);

    // Complete (as the flow's Done path would) and relaunch.
    await onboarding.setOnboardingComplete();
    await pumpShell();
    await pumpSettle(tester);
    expect(find.text(en.homeTitle), findsOneWidget);
    expect(find.text(en.onboardingTitle), findsNothing);
    await finishWidgetTest(tester, stack);
  });
}
