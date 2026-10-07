// Photo mission widget (Phase 4): capture a photo to complete.
//
// Renders a [PhotoMissionController]: the instruction with the optional
// config label, a Take-photo button, a capturing indicator, the
// cancellation hint, and the error state with a retry. Completion is
// reported exactly once.

import 'package:alarmx/core/l10n/app_strings.dart';
import 'package:alarmx/features/missions/mission_config.dart';
import 'package:alarmx/features/missions/photo/photo_mission.dart';
import 'package:flutter/material.dart';

/// Executes one photo [entry], calling [onCompleted] once on success.
class PhotoMissionWidget extends StatefulWidget {
  const PhotoMissionWidget({
    super.key,
    required this.entry,
    required this.onCompleted,
    this.captureSource,
  });

  final MissionEntry entry;
  final VoidCallback onCompleted;

  /// Capture-source override for tests; production uses the system camera.
  final PhotoCaptureSource? captureSource;

  @override
  State<PhotoMissionWidget> createState() => _PhotoMissionWidgetState();
}

class _PhotoMissionWidgetState extends State<PhotoMissionWidget> {
  late final PhotoMissionController _mission;
  bool _reported = false;

  @override
  void initState() {
    super.initState();
    final MissionConfig raw = widget.entry.config;
    _mission = PhotoMissionController(
      label: raw is PhotoMissionConfig ? raw.label.trim() : '',
      captureSource: widget.captureSource ?? ImagePickerPhotoSource(),
    );
    _mission.addListener(_onProgress);
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

  @override
  Widget build(BuildContext context) {
    final AppStrings strings = AppStrings.of(context);
    if (widget.entry.config is! PhotoMissionConfig) {
      return Text(strings.ringingSkippedInvalid);
    }
    final ThemeData theme = Theme.of(context);
    return ListenableBuilder(
      listenable: _mission,
      builder: (BuildContext context, Widget? _) {
        switch (_mission.phase) {
          case PhotoPhase.idle:
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Text(
                  strings.photoInstruction,
                  style: theme.textTheme.titleMedium,
                  textAlign: TextAlign.center,
                ),
                if (_mission.label.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 8),
                  Text(
                    _mission.label,
                    style: theme.textTheme.bodyLarge,
                    textAlign: TextAlign.center,
                  ),
                ],
                if (_mission.cancelledHint) ...<Widget>[
                  const SizedBox(height: 8),
                  Text(
                    strings.photoCancelled,
                    style: theme.textTheme.bodyLarge,
                    textAlign: TextAlign.center,
                  ),
                ],
                const SizedBox(height: 12),
                FilledButton.icon(
                  key: const Key('photo_take_button'),
                  onPressed: _mission.capture,
                  icon: const Icon(Icons.photo_camera_outlined),
                  label: Text(strings.photoTake),
                ),
              ],
            );
          case PhotoPhase.capturing:
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: CircularProgressIndicator(),
              ),
            );
          case PhotoPhase.done:
            return Text(
              strings.missionCompleted,
              style: theme.textTheme.titleMedium,
              textAlign: TextAlign.center,
            );
          case PhotoPhase.error:
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Text(
                  strings.photoError,
                  style: theme.textTheme.titleMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                FilledButton(
                  key: const Key('photo_retry_button'),
                  onPressed: _mission.capture,
                  child: Text(strings.missionRetry),
                ),
              ],
            );
        }
      },
    );
  }
}
