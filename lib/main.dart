// AlarmX production entry point: real app shell (Phase 3).
//
// Startup order:
//   1. App-start reconciliation over a short-lived database connection
//      (reliability infrastructure from Phase 2.6, unchanged). Failure
//      never blocks launch; a later lifecycle event retries.
//   2. The app-lifetime database + repository + coordinator + settings.
//   3. [AlarmxApp]: locale-aware MaterialApp, Home screen, post-fire
//      rescheduling wiring, and persisted language selection.
//
// The temporary native-pipeline test screen is retired by this phase.

import 'package:alarmx/core/alarms/alarm_controller.dart';
import 'package:alarmx/core/alarms/native_alarm_events.dart';
import 'package:alarmx/core/alarms/native_alarm_scheduler_impl.dart';
import 'package:alarmx/core/bootstrap/app_bootstrap.dart';
import 'package:alarmx/core/database/database.dart';
import 'package:alarmx/core/l10n/app_strings.dart';
import 'package:alarmx/core/repositories/alarm_repository.dart';
import 'package:alarmx/core/repositories/app_settings_repository.dart';
import 'package:alarmx/core/repositories/mission_repository.dart';
import 'package:alarmx/core/scheduling/alarm_schedule_result.dart';
import 'package:alarmx/core/scheduling/alarm_scheduling_coordinator.dart';
import 'package:alarmx/features/home/home_screen.dart';
import 'package:alarmx/features/missions/mission_service.dart';
import 'package:alarmx/features/ringing_alarm/ringing_alarm_bridge.dart';
import 'package:alarmx/features/ringing_alarm/ringing_launch.dart';
import 'package:alarmx/features/ringing_alarm/ringing_mission_screen.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

/// Production entry point; see the file docs.
///
/// Widget tests pump [AlarmxApp] directly with injected fakes/in-memory
/// doubles and never call this, so their isolation is unaffected.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await runProductionReconciliation();
  } catch (e) {
    debugPrint('App-start reconciliation failed: $e');
  }
  // App-lifetime database: opened once and intentionally never closed
  // (closing would break the Home stream; the OS reclaims it with the
  // process). Reconciliation above used its own short-lived connection.
  final AppDatabase db = AppDatabase();
  final AlarmRepository repository = DriftAlarmRepository(db.alarmDao);
  runApp(
    AlarmxApp(
      repository: repository,
      coordinator: AlarmSchedulingCoordinator(
        repository: repository,
        scheduler: const NativeAlarmSchedulerImpl(),
      ),
      settings: DriftAppSettingsRepository(db.appSettingsDao),
      missionService: MissionService(DriftMissionRepository(db.missionDao)),
      ringingBridge: MethodChannelRingingBridge(),
    ),
  );
}

/// Root widget: locale-aware app + app-shell services.
///
/// Owns the [AlarmController], the native post-fire listener (routes
/// `onAlarmStopped` to `rescheduleAfterFire` so recurring alarms chain
/// while the app is open), and the persisted UI language.
class AlarmxApp extends StatefulWidget {
  const AlarmxApp({
    super.key,
    required this.repository,
    required this.coordinator,
    required this.settings,
    required this.missionService,
    this.ringingBridge,
    this.events,
  });

  final AlarmRepository repository;
  final AlarmSchedulingCoordinator coordinator;
  final AppSettingsRepository settings;
  final MissionService missionService;

  /// Ringing bridge override; `null` (tests, plain unit shells) boots Home.
  /// Production passes the MethodChannel bridge so ring launches route to
  /// the mission screen.
  final RingingAlarmBridge? ringingBridge;

  /// Event listener override for tests; production uses a live one.
  final NativeAlarmEvents? events;

  @override
  State<AlarmxApp> createState() => _AlarmxAppState();
}

class _AlarmxAppState extends State<AlarmxApp> {
  late final AlarmController _controller = AlarmController(
    repository: widget.repository,
    coordinator: widget.coordinator,
  );
  late final NativeAlarmEvents _events = widget.events ?? NativeAlarmEvents();
  late final Future<AppSetting> _settingsFuture =
      widget.settings.getSettings();
  late final Future<RingingLaunch?>? _launchFuture =
      widget.ringingBridge?.consumeRingingLaunch();

  /// True once a ringing session finished and the shell returned Home.
  bool _ringingFinished = false;

  /// Session language, set by the Home menu (also persisted best-effort).
  String? _languageOverride;

  @override
  void initState() {
    super.initState();
    _events.onAlarmStopped = _handleAlarmStopped;
    _events.attach();
  }

  @override
  void dispose() {
    _events.detach();
    super.dispose();
  }

  Future<void> _handleAlarmStopped(
    int alarmId,
    DateTime firedTriggerAt,
  ) async {
    final AlarmScheduleResult result =
        await widget.coordinator.rescheduleAfterFire(
      alarmId: alarmId,
      firedTriggerAt: firedTriggerAt,
    );
    debugPrint(
      'AlarmxApp: post-fire reschedule for alarm $alarmId: '
      '${_describeResult(result)}',
    );
  }

  String _describeResult(AlarmScheduleResult result) {
    return switch (result) {
      AlarmScheduled(:final triggerAt) => 'scheduled for $triggerAt',
      AlarmNotSchedulable(:final reason) => 'not schedulable ($reason)',
      AlarmDisabled() => 'alarm disabled',
      AlarmPermissionMissing() => 'exact-alarm permission missing',
      AlarmScheduleFailed(:final error) => 'failed ($error)',
    };
  }

  Future<void> _setLanguage(String code) async {
    final String normalized = AppLanguage.normalize(code);
    try {
      await widget.settings.updateSettings(
        AppSettingsCompanion(language: Value(normalized)),
      );
    } catch (e) {
      // Persist failure must not block the switch: the UI still applies
      // the language for this session and the stored value is retried on
      // the next change.
      debugPrint('AlarmxApp: could not persist language: $e');
    }
    if (mounted) {
      setState(() {
        _languageOverride = normalized;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<AppSetting>(
      future: _settingsFuture,
      builder: (BuildContext context, AsyncSnapshot<AppSetting> snapshot) {
        final String languageCode = AppLanguage.normalize(
          _languageOverride ?? snapshot.data?.language,
        );
        return MaterialApp(
          title: 'AlarmX',
          locale: Locale(languageCode),
          supportedLocales: const <Locale>[
            Locale(AppLanguage.arabic),
            Locale(AppLanguage.english),
          ],
          localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: Colors.indigo,
            ),
          ),
          darkTheme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: Colors.indigo,
              brightness: Brightness.dark,
            ),
          ),
          themeMode: _themeModeFrom(snapshot.data?.theme),
          home: _ringingFinished
              ? HomeScreen(
                  controller: _controller,
                  missionService: widget.missionService,
                  languageCode: languageCode,
                  onLanguageChanged: _setLanguage,
                )
              : FutureBuilder<RingingLaunch?>(
                  future: _launchFuture,
                  builder: (
                    BuildContext context,
                    AsyncSnapshot<RingingLaunch?> snapshot,
                  ) {
                    if (snapshot.connectionState ==
                        ConnectionState.waiting) {
                      return const Scaffold(
                        body: Center(child: CircularProgressIndicator()),
                      );
                    }
                    final RingingLaunch? launch = snapshot.data;
                    final RingingAlarmBridge? bridge = widget.ringingBridge;
                    if (launch == null || bridge == null) {
                      return HomeScreen(
                        controller: _controller,
                        missionService: widget.missionService,
                        languageCode: languageCode,
                        onLanguageChanged: _setLanguage,
                      );
                    }
                    return RingingMissionScreen(
                      launch: launch,
                      missionService: widget.missionService,
                      bridge: bridge,
                      onFinished: () {
                        if (mounted) {
                          setState(() {
                            _ringingFinished = true;
                          });
                        }
                      },
                    );
                  },
                ),
        );
      },
    );
  }

  ThemeMode _themeModeFrom(String? theme) {
    switch (theme) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }
}
