// Light mission widget: catch bright light or guide the glow dot.
//
// Renders the configured [LightMode]: Light Catch shows the live lux
// reading with a progress bar toward the target (sampled on a widget-
// owned timer; no sensor keeps anything alive past disposal), and offers
// Glow Dot for this execution when the device reports no sensor. Glow
// Dot shows the drag canvas. Completion is reported exactly once.

import 'dart:async' show Timer;

import 'package:alarmx/core/l10n/app_strings.dart';
import 'package:alarmx/features/missions/light/light_mission.dart';
import 'package:alarmx/features/missions/light/light_sensor_gate.dart';
import 'package:alarmx/features/missions/mission_config.dart';
import 'package:flutter/material.dart';

/// Executes one light [entry], calling [onCompleted] once on success.
class LightMissionWidget extends StatefulWidget {
  const LightMissionWidget({
    super.key,
    required this.entry,
    required this.onCompleted,
    this.gate,
  });

  final MissionEntry entry;
  final VoidCallback onCompleted;

  /// Sensor-gate override for tests; production reads the real sensor.
  final LightSensorGate? gate;

  @override
  State<LightMissionWidget> createState() => _LightMissionWidgetState();
}

class _LightMissionWidgetState extends State<LightMissionWidget> {
  late LightCatchController _catch;
  late final GlowDotController _glow = GlowDotController();
  Timer? _timer;
  bool _useGlow = false;
  bool _reported = false;

  @override
  void initState() {
    super.initState();
    _catch = LightCatchController(
      gate: widget.gate ?? const MethodChannelLightSensor(),
    );
    _catch.addListener(_onCatchProgress);
    _glow.addListener(_onGlowProgress);
    if (_configuredMode() == LightMode.lightCatch) {
      _timer = Timer.periodic(kLightCatchPollInterval, (_) {
        _catch.sample();
      });
      _catch.sample();
    } else {
      _useGlow = true;
    }
  }

  LightMode _configuredMode() {
    final MissionConfig raw = widget.entry.config;
    return raw is LightMissionConfig ? raw.mode : LightMode.lightCatch;
  }

  @override
  void dispose() {
    _timer?.cancel();
    _catch.removeListener(_onCatchProgress);
    _glow.removeListener(_onGlowProgress);
    _catch.dispose();
    _glow.dispose();
    super.dispose();
  }

  void _onCatchProgress() {
    if (_catch.isDone) {
      _timer?.cancel();
      _report();
    }
    if (mounted) {
      setState(() {});
    }
  }

  void _onGlowProgress() {
    if (_glow.isDone) {
      _report();
    }
    if (mounted) {
      setState(() {});
    }
  }

  void _report() {
    if (!_reported) {
      _reported = true;
      widget.onCompleted();
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppStrings strings = AppStrings.of(context);
    if (widget.entry.config is! LightMissionConfig) {
      return Text(strings.ringingSkippedInvalid);
    }
    if (_catch.isDone || _glow.isDone) {
      return Text(
        strings.missionCompleted,
        style: Theme.of(context).textTheme.titleMedium,
        textAlign: TextAlign.center,
      );
    }
    if (_useGlow) {
      return _GlowBoard(controller: _glow);
    }
    return _CatchBoard(
      controller: _catch,
      onGlowInstead: () {
        _timer?.cancel();
        setState(() {
          _useGlow = true;
        });
      },
    );
  }
}

/// Light Catch board: live lux, progress bar, and the no-sensor escape
/// hatch to Glow Dot for this execution.
class _CatchBoard extends StatelessWidget {
  const _CatchBoard({required this.controller, required this.onGlowInstead});

  final LightCatchController controller;
  final VoidCallback onGlowInstead;

  @override
  Widget build(BuildContext context) {
    final AppStrings strings = AppStrings.of(context);
    final ThemeData theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          strings.lightCatchInstruction,
          style: theme.textTheme.titleMedium,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Icon(
              Icons.lightbulb_outline,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(width: 8),
            Text(
              key: const Key('light_lux'),
              '${strings.lightLux}: ${controller.lux?.round() ?? '…'} '
              '/ ${kLightCatchTargetLux.round()}',
              style: theme.textTheme.bodyLarge,
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: controller.progress,
            minHeight: 12,
          ),
        ),
        if (controller.needsFallback) ...<Widget>[
          const SizedBox(height: 12),
          Text(
            strings.lightNoSensor,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.error,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          FilledButton.tonal(
            key: const Key('light_glow_instead'),
            onPressed: onGlowInstead,
            child: Text(strings.lightUseGlowInstead),
          ),
        ],
      ],
    );
  }
}

/// Glow Dot board: drag the glowing dot into the ring.
class _GlowBoard extends StatelessWidget {
  const _GlowBoard({required this.controller});

  final GlowDotController controller;

  @override
  Widget build(BuildContext context) {
    final AppStrings strings = AppStrings.of(context);
    final ThemeData theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          strings.lightGlowInstruction,
          style: theme.textTheme.titleMedium,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            final Size size = Size(
              constraints.maxWidth,
              300,
            );
            return GestureDetector(
              key: const Key('glow_canvas'),
              behavior: HitTestBehavior.opaque,
              onPanStart: (DragStartDetails details) =>
                  _move(details.localPosition, size),
              onPanUpdate: (DragUpdateDetails details) =>
                  _move(details.localPosition, size),
              child: CustomPaint(
                size: size,
                painter: _GlowPainter(
                  dot: controller.dot,
                  socket: controller.socket,
                  snapRadius: controller.snapRadius,
                  glowColor: theme.colorScheme.primary,
                  socketColor: theme.colorScheme.tertiary,
                  backgroundColor:
                      theme.colorScheme.surfaceContainerHighest,
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  void _move(Offset local, Size size) {
    controller.move(
      Offset(
        local.dx / size.width,
        local.dy / size.height,
      ),
    );
  }
}

/// Paints the socket ring, the faint guide line, and the glowing dot.
class _GlowPainter extends CustomPainter {
  const _GlowPainter({
    required this.dot,
    required this.socket,
    required this.snapRadius,
    required this.glowColor,
    required this.socketColor,
    required this.backgroundColor,
  });

  final Offset dot;
  final Offset socket;
  final double snapRadius;
  final Color glowColor;
  final Color socketColor;
  final Color backgroundColor;

  @override
  void paint(Canvas canvas, Size size) {
    final Rect board = Offset.zero & size;
    canvas.drawRRect(
      RRect.fromRectAndRadius(board, const Radius.circular(20)),
      Paint()..color = backgroundColor,
    );
    final Offset dotPx =
        Offset(dot.dx * size.width, dot.dy * size.height);
    final Offset socketPx =
        Offset(socket.dx * size.width, socket.dy * size.height);
    final double unit = size.shortestSide;

    canvas.drawLine(
      dotPx,
      socketPx,
      Paint()
        ..color = glowColor.withValues(alpha: 0.35)
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawCircle(
      socketPx,
      snapRadius * unit + 14,
      Paint()
        ..color = socketColor.withValues(alpha: 0.25)
        ..style = PaintingStyle.fill,
    );
    canvas.drawCircle(
      socketPx,
      snapRadius * unit + 14,
      Paint()
        ..color = socketColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
    canvas.drawCircle(
      dotPx,
      26,
      Paint()
        ..color = glowColor.withValues(alpha: 0.25)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12),
    );
    canvas.drawCircle(dotPx, 14, Paint()..color = glowColor);
    canvas.drawCircle(dotPx, 5, Paint()..color = const Color(0xFFFFFFFF));
  }

  @override
  bool shouldRepaint(_GlowPainter oldDelegate) {
    return oldDelegate.dot != dot;
  }
}
