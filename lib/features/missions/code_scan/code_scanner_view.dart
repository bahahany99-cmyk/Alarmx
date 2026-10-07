// Production camera scanner view (Phase 4).
//
// Thin wrapper over the `mobile_scanner` package (the single scanner used
// for both QR and barcode missions): owns a [MobileScannerController] for
// [formats], starts it when the view appears, forwards the first detected
// code value via [onCode], and stops + disposes the controller when the
// view goes away, so the camera is never left running.
//
// This is the only file (besides the thin type wrappers) that imports the
// scanner package. Widget tests inject a stub view instead and drive the
// mission controller directly, so CI never touches a real camera.

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

/// Live scanner camera view; see the file docs.
class CodeScannerView extends StatefulWidget {
  const CodeScannerView({
    super.key,
    required this.formats,
    required this.onCode,
    required this.onError,
  });

  /// Formats to detect (QR-only for the QR mission, all for barcodes).
  final List<BarcodeFormat> formats;

  /// Called with each detected code value (`null` when unreadable).
  final ValueChanged<String?> onCode;

  /// Called once when the scanner reports an error.
  final VoidCallback onError;

  @override
  State<CodeScannerView> createState() => _CodeScannerViewState();
}

class _CodeScannerViewState extends State<CodeScannerView> {
  late final MobileScannerController _controller = MobileScannerController(
    formats: widget.formats,
    autoStart: false,
  );
  bool _errorReported = false;

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    try {
      await _controller.start();
    } catch (_) {
      _reportError();
    }
  }

  void _reportError() {
    if (_errorReported || !mounted) {
      return;
    }
    _errorReported = true;
    widget.onError();
  }

  @override
  void dispose() {
    try {
      _controller.stop();
    } catch (_) {
      // Best effort: teardown must not throw.
    }
    try {
      _controller.dispose();
    } catch (_) {
      // Best effort: teardown must not throw.
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MobileScanner(
      controller: _controller,
      onDetect: (BarcodeCapture capture) {
        final List<Barcode> barcodes = capture.barcodes;
        widget.onCode(
          barcodes.isEmpty ? null : barcodes.first.rawValue,
        );
      },
      onDetectError: (Object error, StackTrace stackTrace) {
        _reportError();
      },
      errorBuilder:
          (BuildContext context, MobileScannerException error) {
        // Runs during build: schedule the report post-frame (calling back
        // synchronously here would notify listeners mid-build).
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _reportError();
        });
        return const Center(
          child: Icon(Icons.videocam_off_outlined, size: 64),
        );
      },
    );
  }
}
