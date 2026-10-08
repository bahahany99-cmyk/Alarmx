// Tests for the shared QR/barcode scan mission: value checking, the
// permission/scanning phase machine, cancellation, errors, the phase
// widget (with a stub scanner view), and the thin type wrappers.

import 'package:alarmx/core/l10n/app_strings.dart';
import 'package:alarmx/core/models/models.dart';
import 'package:alarmx/features/missions/barcode/barcode_mission_widget.dart';
import 'package:alarmx/features/missions/code_scan/code_scan_mission.dart';
import 'package:alarmx/features/missions/code_scan/code_scan_mission_widget.dart';
import 'package:alarmx/features/missions/mission_config.dart';
import 'package:alarmx/features/missions/permissions/camera_permission.dart';
import 'package:alarmx/features/missions/qr/qr_mission_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/test_doubles.dart';

/// Scripted permission gate for tests.
class FakeCameraPermissionGate implements CameraPermissionGate {
  CameraPermissionOutcome nextOutcome = CameraPermissionOutcome.granted;
  CameraPermissionOutcome currentStatus = CameraPermissionOutcome.granted;
  int requests = 0;
  int checks = 0;
  int settingsOpened = 0;

  @override
  Future<CameraPermissionOutcome> requestCamera() async {
    requests++;
    return nextOutcome;
  }

  @override
  Future<CameraPermissionOutcome> checkCameraStatus() async {
    checks++;
    return currentStatus;
  }

  @override
  Future<void> openSettings() async {
    settingsOpened++;
  }
}

/// Stub camera view: buttons drive the controller directly, so no real
/// camera is ever touched. Records the nonces it was built with.
class StubScanner {
  StubScanner(this.expected);

  final String expected;
  final List<int> nonces = <int>[];

  Widget build(
    BuildContext context,
    CodeScanMissionController controller,
    int nonce,
  ) {
    nonces.add(nonce);
    return Column(
      children: <Widget>[
        TextButton(
          key: const Key('stub_scan_correct'),
          onPressed: () => controller.onCodeDetected(expected),
          child: const Text('correct'),
        ),
        TextButton(
          key: const Key('stub_scan_wrong'),
          onPressed: () => controller.onCodeDetected('WRONG-CODE'),
          child: const Text('wrong'),
        ),
        TextButton(
          key: const Key('stub_scan_error'),
          onPressed: controller.onScannerError,
          child: const Text('error'),
        ),
      ],
    );
  }
}

Future<void> pumpScan(
  WidgetTester tester, {
  required String expectedValue,
  required FakeCameraPermissionGate gate,
  required StubScanner stub,
  required VoidCallback onCompleted,
  String instruction = 'Scan now',
}) async {
  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale(AppLanguage.english),
      supportedLocales: testLocales,
      localizationsDelegates: testDelegates,
      home: Scaffold(
        body: SingleChildScrollView(
          child: CodeScanMissionWidget(
            instruction: instruction,
            expectedValue: expectedValue,
            formats: const [],
            onCompleted: onCompleted,
            permissionGate: gate,
            scannerBuilder: stub.build,
          ),
        ),
      ),
    ),
  );
  await pumpSettle(tester);
}

void main() {
  group('checkScannedValue', () {
    test('correct values succeed', () {
      expect(checkScannedValue('CODE-1', 'CODE-1'), isTrue);
      expect(checkScannedValue('  CODE-1 ', 'CODE-1'), isTrue);
      expect(checkScannedValue('CODE-1', '  CODE-1  '), isTrue);
    });

    test('wrong, empty and null scans fail', () {
      expect(checkScannedValue('CODE-1', 'CODE-2'), isFalse);
      expect(checkScannedValue('CODE-1', 'code-1'), isFalse);
      expect(checkScannedValue('CODE-1', ''), isFalse);
      expect(checkScannedValue('CODE-1', null), isFalse);
      expect(checkScannedValue('', 'CODE-1'), isFalse);
      expect(checkScannedValue('   ', '   '), isFalse);
    });
  });

  group('CodeScanMissionController', () {
    test('granted permission enters scanning with a fresh nonce', () async {
      final FakeCameraPermissionGate gate = FakeCameraPermissionGate();
      final CodeScanMissionController controller =
          CodeScanMissionController(
        expectedValue: 'CODE-1',
        permissionGate: gate,
      );
      addTearDown(controller.dispose);
      expect(controller.phase, CodeScanPhase.idle);
      await controller.start();
      expect(controller.phase, CodeScanPhase.scanning);
      expect(controller.scanNonce, 1);
      expect(gate.requests, 1);
    });

    test('concurrent starts collapse into one request', () async {
      final FakeCameraPermissionGate gate = FakeCameraPermissionGate();
      final CodeScanMissionController controller =
          CodeScanMissionController(
        expectedValue: 'CODE-1',
        permissionGate: gate,
      );
      addTearDown(controller.dispose);
      await Future.wait(<Future<void>>[
        controller.start(),
        controller.start(),
      ]);
      expect(gate.requests, 1);
      expect(controller.phase, CodeScanPhase.scanning);
    });

    test('denied then granted recovers', () async {
      final FakeCameraPermissionGate gate = FakeCameraPermissionGate()
        ..nextOutcome = CameraPermissionOutcome.denied;
      final CodeScanMissionController controller =
          CodeScanMissionController(
        expectedValue: 'CODE-1',
        permissionGate: gate,
      );
      addTearDown(controller.dispose);
      await controller.start();
      expect(controller.phase, CodeScanPhase.permissionDenied);
      gate.nextOutcome = CameraPermissionOutcome.granted;
      await controller.start();
      expect(controller.phase, CodeScanPhase.scanning);
      expect(controller.scanNonce, 1);
    });

    test('permanently denied opens settings', () async {
      final FakeCameraPermissionGate gate = FakeCameraPermissionGate()
        ..nextOutcome = CameraPermissionOutcome.permanentlyDenied;
      final CodeScanMissionController controller =
          CodeScanMissionController(
        expectedValue: 'CODE-1',
        permissionGate: gate,
      );
      addTearDown(controller.dispose);
      await controller.start();
      expect(
        controller.phase,
        CodeScanPhase.permissionPermanentlyDenied,
      );
      await controller.openSettings();
      expect(gate.settingsOpened, 1);
    });

    test('wrong scan hints and keeps scanning; correct completes', () async {
      final CodeScanMissionController controller =
          CodeScanMissionController(
        expectedValue: 'CODE-1',
        permissionGate: FakeCameraPermissionGate(),
      );
      addTearDown(controller.dispose);
      await controller.start();
      controller.onCodeDetected('NOPE');
      expect(controller.phase, CodeScanPhase.scanning);
      expect(controller.wrongAttempt, isTrue);
      expect(controller.isDone, isFalse);
      controller.onCodeDetected('  CODE-1 ');
      expect(controller.phase, CodeScanPhase.done);
      expect(controller.isDone, isTrue);
      expect(controller.wrongAttempt, isFalse);
      // Detections after completion are ignored.
      controller.onCodeDetected('NOPE');
      expect(controller.phase, CodeScanPhase.done);
    });

    test('null scan counts as a wrong attempt', () async {
      final CodeScanMissionController controller =
          CodeScanMissionController(
        expectedValue: 'CODE-1',
        permissionGate: FakeCameraPermissionGate(),
      );
      addTearDown(controller.dispose);
      await controller.start();
      controller.onCodeDetected(null);
      expect(controller.wrongAttempt, isTrue);
      expect(controller.phase, CodeScanPhase.scanning);
    });

    test('error then retry re-enters scanning with a new nonce', () async {
      final CodeScanMissionController controller =
          CodeScanMissionController(
        expectedValue: 'CODE-1',
        permissionGate: FakeCameraPermissionGate(),
      );
      addTearDown(controller.dispose);
      await controller.start();
      controller.onScannerError();
      expect(controller.phase, CodeScanPhase.error);
      await controller.start();
      expect(controller.phase, CodeScanPhase.scanning);
      expect(controller.scanNonce, 2);
    });

    test('cancel returns to idle; cancel after done is a no-op', () async {
      final CodeScanMissionController controller =
          CodeScanMissionController(
        expectedValue: 'CODE-1',
        permissionGate: FakeCameraPermissionGate(),
      );
      addTearDown(controller.dispose);
      controller.cancelScan();
      expect(controller.phase, CodeScanPhase.idle);
      await controller.start();
      controller.onCodeDetected('NOPE');
      controller.cancelScan();
      expect(controller.phase, CodeScanPhase.idle);
      expect(controller.wrongAttempt, isFalse);
      await controller.start();
      controller.onCodeDetected('CODE-1');
      controller.cancelScan();
      expect(controller.phase, CodeScanPhase.done);
      // Start after done is a no-op (no new permission request).
      await controller.start();
      expect(controller.phase, CodeScanPhase.done);
    });

    test('detections and errors are ignored outside scanning', () async {
      final CodeScanMissionController controller =
          CodeScanMissionController(
        expectedValue: 'CODE-1',
        permissionGate: FakeCameraPermissionGate(),
      );
      addTearDown(controller.dispose);
      controller.onCodeDetected('CODE-1');
      controller.onScannerError();
      expect(controller.phase, CodeScanPhase.idle);
    });
  });

  group('CodeScanMissionWidget', () {
    final AppStrings en = AppStrings.forCode(AppLanguage.english);

    testWidgets('granted permission shows the scanner and completes',
        (WidgetTester tester) async {
      final StubScanner stub = StubScanner('CODE-1');
      int completions = 0;
      await pumpScan(
        tester,
        expectedValue: 'CODE-1',
        gate: FakeCameraPermissionGate(),
        stub: stub,
        onCompleted: () {
          completions++;
        },
      );
      expect(find.byKey(const Key('stub_scan_correct')), findsOneWidget);
      expect(stub.nonces, <int>[1]);
      await tester.tap(find.byKey(const Key('stub_scan_correct')));
      await pumpSettle(tester);
      expect(completions, 1);
      expect(find.text(en.missionCompleted), findsOneWidget);
      expect(find.byKey(const Key('stub_scan_correct')), findsNothing);
    });

    testWidgets('wrong scan shows the hint and keeps scanning',
        (WidgetTester tester) async {
      int completions = 0;
      await pumpScan(
        tester,
        expectedValue: 'CODE-1',
        gate: FakeCameraPermissionGate(),
        stub: StubScanner('CODE-1'),
        onCompleted: () {
          completions++;
        },
      );
      await tester.tap(find.byKey(const Key('stub_scan_wrong')));
      await pumpSettle(tester);
      expect(find.text(en.scanWrongCode), findsOneWidget);
      expect(completions, 0);
      await tester.tap(find.byKey(const Key('stub_scan_correct')));
      await pumpSettle(tester);
      expect(completions, 1);
    });

    testWidgets('denied permission offers allow-again',
        (WidgetTester tester) async {
      final FakeCameraPermissionGate gate = FakeCameraPermissionGate()
        ..nextOutcome = CameraPermissionOutcome.denied;
      await pumpScan(
        tester,
        expectedValue: 'CODE-1',
        gate: gate,
        stub: StubScanner('CODE-1'),
        onCompleted: () {},
      );
      expect(find.text(en.permissionDenied), findsOneWidget);
      expect(find.byKey(const Key('scan_allow_button')), findsOneWidget);
      gate.nextOutcome = CameraPermissionOutcome.granted;
      await tester.tap(find.byKey(const Key('scan_allow_button')));
      await pumpSettle(tester);
      expect(find.byKey(const Key('stub_scan_correct')), findsOneWidget);
    });

    testWidgets('permanently denied offers app settings',
        (WidgetTester tester) async {
      final FakeCameraPermissionGate gate = FakeCameraPermissionGate()
        ..nextOutcome = CameraPermissionOutcome.permanentlyDenied;
      await pumpScan(
        tester,
        expectedValue: 'CODE-1',
        gate: gate,
        stub: StubScanner('CODE-1'),
        onCompleted: () {},
      );
      expect(find.byKey(const Key('scan_settings_button')), findsOneWidget);
      await tester.tap(find.byKey(const Key('scan_settings_button')));
      await pumpSettle(tester);
      expect(gate.settingsOpened, 1);
    });

    testWidgets('cancel returns to idle and restart uses a fresh view',
        (WidgetTester tester) async {
      final StubScanner stub = StubScanner('CODE-1');
      await pumpScan(
        tester,
        expectedValue: 'CODE-1',
        gate: FakeCameraPermissionGate(),
        stub: stub,
        onCompleted: () {},
      );
      await tester.tap(find.byKey(const Key('scan_cancel_button')));
      await pumpSettle(tester);
      expect(find.byKey(const Key('scan_start_button')), findsOneWidget);
      expect(find.byKey(const Key('stub_scan_correct')), findsNothing);
      await tester.tap(find.byKey(const Key('scan_start_button')));
      await pumpSettle(tester);
      expect(find.byKey(const Key('stub_scan_correct')), findsOneWidget);
      expect(stub.nonces, <int>[1, 2]);
    });

    testWidgets('scanner error shows retry and recovers',
        (WidgetTester tester) async {
      await pumpScan(
        tester,
        expectedValue: 'CODE-1',
        gate: FakeCameraPermissionGate(),
        stub: StubScanner('CODE-1'),
        onCompleted: () {},
      );
      await tester.tap(find.byKey(const Key('stub_scan_error')));
      await pumpSettle(tester);
      expect(find.text(en.scanError), findsOneWidget);
      expect(find.byKey(const Key('scan_retry_button')), findsOneWidget);
      await tester.tap(find.byKey(const Key('scan_retry_button')));
      await pumpSettle(tester);
      expect(find.byKey(const Key('stub_scan_correct')), findsOneWidget);
    });
  });

  group('type wrappers', () {
    final AppStrings en = AppStrings.forCode(AppLanguage.english);

    Future<void> pumpWrapper(WidgetTester tester, Widget child) async {
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale(AppLanguage.english),
          supportedLocales: testLocales,
          localizationsDelegates: testDelegates,
          home: Scaffold(
            body: SingleChildScrollView(child: child),
          ),
        ),
      );
      await pumpSettle(tester);
    }

    MissionEntry entryOf(MissionType type, MissionConfig config) {
      return MissionEntry(
        id: 1,
        alarmId: 9,
        type: type,
        orderIndex: 0,
        config: config,
        required: true,
      );
    }

    testWidgets('QR wrapper shows the QR instruction and completes',
        (WidgetTester tester) async {
      int completions = 0;
      final StubScanner stub = StubScanner('QR-1');
      await pumpWrapper(
        tester,
        QrMissionWidget(
          entry: entryOf(
            MissionType.qr,
            const QrMissionConfig('QR-1'),
          ),
          onCompleted: () {
            completions++;
          },
          permissionGate: FakeCameraPermissionGate(),
          scannerBuilder: stub.build,
        ),
      );
      expect(find.text(en.qrInstruction), findsOneWidget);
      await tester.tap(find.byKey(const Key('stub_scan_correct')));
      await pumpSettle(tester);
      expect(completions, 1);
    });

    testWidgets('barcode wrapper shows the barcode instruction',
        (WidgetTester tester) async {
      await pumpWrapper(
        tester,
        BarcodeMissionWidget(
          entry: entryOf(
            MissionType.barcode,
            const BarcodeMissionConfig('BC-1'),
          ),
          onCompleted: () {},
          permissionGate: FakeCameraPermissionGate(),
          scannerBuilder: StubScanner('BC-1').build,
        ),
      );
      expect(find.text(en.barcodeInstruction), findsOneWidget);
    });

    testWidgets('mismatched configs render invalid, never crash',
        (WidgetTester tester) async {
      await pumpWrapper(
        tester,
        QrMissionWidget(
          entry: entryOf(
            MissionType.qr,
            const BarcodeMissionConfig('BC-1'),
          ),
          onCompleted: () {},
          permissionGate: FakeCameraPermissionGate(),
          scannerBuilder: StubScanner('x').build,
        ),
      );
      expect(find.text(en.ringingSkippedInvalid), findsOneWidget);
      await pumpWrapper(
        tester,
        BarcodeMissionWidget(
          entry: entryOf(
            MissionType.barcode,
            const QrMissionConfig('QR-1'),
          ),
          onCompleted: () {},
          permissionGate: FakeCameraPermissionGate(),
          scannerBuilder: StubScanner('x').build,
        ),
      );
      expect(find.text(en.ringingSkippedInvalid), findsOneWidget);
    });
  });
}
