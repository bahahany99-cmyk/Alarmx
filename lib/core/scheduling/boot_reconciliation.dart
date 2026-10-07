// Headless entry point for system lifecycle schedule reconciliation.
//
// `BootReceiver` / `AlarmLifecycleReceiver` (native, no UI, no activity)
// spin up a short-lived headless FlutterEngine and execute
// [reconcileAfterBoot], which runs the shared production bootstrap and
// reports completion back over the scheduler channel
// (`onReconcileComplete`). Native destroys the engine afterwards.
//
// Scheduling truth stays in Dart: this file contains no recurrence math —
// the bootstrap reuses the exact database/coordinator/scheduler objects the
// UI path uses. In release builds the function survives tree-shaking via
// `vm:entry-point`; its name must match `HeadlessReconcileRunner`'s
// `DART_ENTRYPOINT`.

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../bootstrap/app_bootstrap.dart';
import 'alarm_schedule_result.dart';

/// Shared scheduler channel (must match `AlarmSchedulerChannelHandler`).
const MethodChannel _reconcileChannel =
    MethodChannel('com.alarmx.app.alarmx/alarm_scheduler');

/// Reconciles stored alarms with the OS from a headless engine.
///
/// Always attempts the `onReconcileComplete` handshake, even on failure, so
/// native can release the engine. `ok` is true when the pass completed
/// (per-alarm problems are inside the report counters); otherwise `error`
/// names the catastrophic failure (e.g. database unusable).
@pragma('vm:entry-point')
Future<void> reconcileAfterBoot() async {
  WidgetsFlutterBinding.ensureInitialized();
  final Map<String, Object?> payload = <String, Object?>{'ok': false};
  try {
    final ReconciliationReport report = await runProductionReconciliation();
    payload['ok'] = true;
    payload.addAll(report.toMap());
  } catch (e) {
    payload['error'] = e.toString();
  }
  try {
    await _reconcileChannel.invokeMethod<void>('onReconcileComplete', payload);
  } catch (_) {
    // Native side already gone (timeout); nothing left to report to.
  }
}
