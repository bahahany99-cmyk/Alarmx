// Shared QR/barcode scan mission widget (Phase 4).
//
// Renders a [CodeScanMissionController]'s phases: requesting indicator,
// recoverable permission states (deny-again / open-settings), the live
// scanner view while scanning, wrong-code hints that keep the mission
// active, and cancellation back to idle. Scanning starts automatically
// when the mission appears (camera permission is requested just-in-time
// at that moment, never before) and the scanner view is released on
// completion, cancellation, or disposal.
//
// The live camera view is built by [scannerBuilder] (production: the
// `mobile_scanner`-backed [CodeScannerView]); tests inject a stub and
// drive the controller directly, so CI never touches a real camera.

import 'package:alarmx/core/l10n/app_strings.dart';
import 'package:alarmx/features/missions/code_scan/code_scan_mission.dart';
import 'package:alarmx/features/missions/code_scan/code_scanner_view.dart';
import 'package:alarmx/features/missions/permissions/camera_permission.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart'
    show BarcodeFormat;

/// Builds the scanner camera view for a scan attempt ([nonce] changes on
/// every entry into the scanning phase so each attempt gets a fresh view).
typedef ScannerViewBuilder = Widget Function(
  BuildContext context,
  CodeScanMissionController controller,
  int nonce,
);

/// Executes one scan mission, calling [onCompleted] once on success.
class CodeScanMissionWidget extends StatefulWidget {
  const CodeScanMissionWidget({
    super.key,
    required this.instruction,
    required this.expectedValue,
    required this.formats,
    required this.onCompleted,
    this.permissionGate = const PermissionHandlerCameraGate(),
    this.scannerBuilder,
  });

  /// Instruction line shown above the scanner (type-specific).
  final String instruction;

  /// Configured expected code value.
  final String expectedValue;

  /// Formats the scanner detects (QR-only vs all barcodes).
  final List<BarcodeFormat> formats;

  final VoidCallback onCompleted;

  /// Permission-gate override for tests; production requests for real.
  final CameraPermissionGate permissionGate;

  /// Scanner-view override for tests; production builds [CodeScannerView].
  final ScannerViewBuilder? scannerBuilder;

  @override
  State<CodeScanMissionWidget> createState() => _CodeScanMissionWidgetState();
}

class _CodeScanMissionWidgetState extends State<CodeScanMissionWidget> {
  late final CodeScanMissionController _mission =
      CodeScanMissionController(
    expectedValue: widget.expectedValue,
    permissionGate: widget.permissionGate,
  );
  bool _reported = false;

  @override
  void initState() {
    super.initState();
    _mission.addListener(_onProgress);
    _mission.start();
  }

  @override
  void dispose() {
    _mission.removeListener(_onProgress);
    _mission.dispose();
    super.dispose();
  }

  void _onProgress() {
    if (_mission.isDone && !_reported) {
      _reported = true;
      widget.onCompleted();
    }
  }

  Widget _scannerView(BuildContext context) {
    final ScannerViewBuilder? custom = widget.scannerBuilder;
    if (custom != null) {
      return custom(context, _mission, _mission.scanNonce);
    }
    return CodeScannerView(
      key: ValueKey<int>(_mission.scanNonce),
      formats: widget.formats,
      onCode: _mission.onCodeDetected,
      onError: _mission.onScannerError,
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppStrings strings = AppStrings.of(context);
    final ThemeData theme = Theme.of(context);
    return ListenableBuilder(
      listenable: _mission,
      builder: (BuildContext context, Widget? _) {
        switch (_mission.phase) {
          case CodeScanPhase.idle:
            return FilledButton(
              key: const Key('scan_start_button'),
              onPressed: _mission.start,
              child: Text(strings.missionRetry),
            );
          case CodeScanPhase.requestingPermission:
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: CircularProgressIndicator(),
              ),
            );
          case CodeScanPhase.permissionDenied:
            return _PermissionState(
              message: strings.permissionDenied,
              actionKey: const Key('scan_allow_button'),
              actionLabel: strings.permissionAllow,
              onAction: _mission.start,
              onCancel: _mission.cancelScan,
            );
          case CodeScanPhase.permissionPermanentlyDenied:
            return _PermissionState(
              message: strings.permissionDenied,
              actionKey: const Key('scan_settings_button'),
              actionLabel: strings.permissionOpenSettings,
              onAction: _mission.openSettings,
              onCancel: _mission.cancelScan,
            );
          case CodeScanPhase.scanning:
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Text(
                  widget.instruction,
                  style: theme.textTheme.titleMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 320,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: _scannerView(context),
                  ),
                ),
                if (_mission.wrongAttempt) ...<Widget>[
                  const SizedBox(height: 8),
                  Text(
                    strings.scanWrongCode,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: theme.colorScheme.error,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
                const SizedBox(height: 12),
                OutlinedButton(
                  key: const Key('scan_cancel_button'),
                  onPressed: _mission.cancelScan,
                  child: Text(strings.scanCancel),
                ),
              ],
            );
          case CodeScanPhase.done:
            return Text(
              strings.missionCompleted,
              style: theme.textTheme.titleMedium,
              textAlign: TextAlign.center,
            );
          case CodeScanPhase.error:
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Text(
                  strings.scanError,
                  style: theme.textTheme.titleMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                FilledButton(
                  key: const Key('scan_retry_button'),
                  onPressed: _mission.start,
                  child: Text(strings.missionRetry),
                ),
                const SizedBox(height: 8),
                OutlinedButton(
                  key: const Key('scan_cancel_button'),
                  onPressed: _mission.cancelScan,
                  child: Text(strings.scanCancel),
                ),
              ],
            );
        }
      },
    );
  }
}

/// Permission recovery state: message + primary action + cancel.
class _PermissionState extends StatelessWidget {
  const _PermissionState({
    required this.message,
    required this.actionKey,
    required this.actionLabel,
    required this.onAction,
    required this.onCancel,
  });

  final String message;
  final Key actionKey;
  final String actionLabel;
  final VoidCallback onAction;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final AppStrings strings = AppStrings.of(context);
    final ThemeData theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          message,
          style: theme.textTheme.titleMedium,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        FilledButton(
          key: actionKey,
          onPressed: onAction,
          child: Text(actionLabel),
        ),
        const SizedBox(height: 8),
        OutlinedButton(
          key: const Key('scan_cancel_button'),
          onPressed: onCancel,
          child: Text(strings.scanCancel),
        ),
      ],
    );
  }
}
