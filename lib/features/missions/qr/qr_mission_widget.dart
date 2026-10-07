// QR mission widget (Phase 4): scan the enrolled QR code.
//
// Thin wrapper over the shared scan mission: QR instruction, QR-only
// format filter, completion exactly once.

import 'package:alarmx/core/l10n/app_strings.dart';
import 'package:alarmx/features/missions/code_scan/code_scan_mission_widget.dart';
import 'package:alarmx/features/missions/mission_config.dart';
import 'package:alarmx/features/missions/permissions/camera_permission.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart' show BarcodeFormat;

/// Executes one QR [entry], calling [onCompleted] once on success.
class QrMissionWidget extends StatelessWidget {
  const QrMissionWidget({
    super.key,
    required this.entry,
    required this.onCompleted,
    this.permissionGate = const PermissionHandlerCameraGate(),
    this.scannerBuilder,
  });

  final MissionEntry entry;
  final VoidCallback onCompleted;

  /// Permission-gate override for tests; production requests for real.
  final CameraPermissionGate permissionGate;

  /// Scanner-view override for tests; production builds the live view.
  final ScannerViewBuilder? scannerBuilder;

  @override
  Widget build(BuildContext context) {
    final AppStrings strings = AppStrings.of(context);
    final MissionConfig raw = entry.config;
    if (raw is! QrMissionConfig) {
      return Text(strings.ringingSkippedInvalid);
    }
    return CodeScanMissionWidget(
      instruction: strings.qrInstruction,
      expectedValue: raw.expectedValue,
      formats: const <BarcodeFormat>[BarcodeFormat.qrCode],
      onCompleted: onCompleted,
      permissionGate: permissionGate,
      scannerBuilder: scannerBuilder,
    );
  }
}
