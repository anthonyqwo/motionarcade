import 'dart:async';
import 'package:flutter/material.dart';

import '../network/connection_status.dart';
import '../shared/models/motion_event.dart';
import '../shared/models/player.dart';
import '../shared/visual/depth_transform.dart';
import '../shared/visual/trail_renderer.dart';
import '../shared/visual/trail_impact_locator.dart';
import '../shared/visual/screen_shake_controller.dart';
import '../shared/visual/particle_system.dart';

class GameShellPage extends StatefulWidget {
  const GameShellPage({
    super.key,
    required this.status,
    required this.players,
    required this.trailPoints,
    required this.trailTransportLabel,
    required this.lastSlash,
    required this.lastEventLabel,
    this.targetDirection = MotionDirection.up,
  });

  final ConnectionStatus status;
  final List<Player> players;
  final List<TrailRenderPoint> trailPoints;
  final String trailTransportLabel;
  final SlashEvent? lastSlash;
  final String lastEventLabel;
  final MotionDirection targetDirection;

  @override
  State<GameShellPage> createState() => _GameShellPageState();
}

class _GameShellPageState extends State<GameShellPage> {
  Timer? _ticker;
  final ValueNotifier<DateTime> _frameClock = ValueNotifier<DateTime>(
    DateTime.now(),
  );
  final ScreenShakeController _shakeController = ScreenShakeController();
  final List<Particle> _particles = [];
  Size _previewSize = const Size(800, 450);

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(milliseconds: 33), (_) {
      if (mounted) {
        final now = DateTime.now();
        _particles.removeWhere((p) => !p.isAlive(now));
        _frameClock.value = now;
      }
    });
  }

  @override
  void didUpdateWidget(GameShellPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.lastSlash != oldWidget.lastSlash && widget.lastSlash != null) {
      final slash = widget.lastSlash!;
      _shakeController.trigger(
        intensity: 8.0 + slash.power * 12.0,
        duration: const Duration(milliseconds: 250),
      );

      final origin = const TrailImpactLocator().locate(
        slash: slash,
        points: widget.trailPoints,
        size: _previewSize,
      );

      final Color color = slash.direction == MotionDirection.forward
          ? const Color(0xFF22C55E)
          : const Color(0xFFFF4EBD);

      final burst = const ParticleBurstFactory().createBurst(
        origin: origin,
        now: DateTime.now(),
        color: color,
        count: 24,
        speed: 55.0 + slash.power * 35.0,
      );
      _particles.addAll(burst);
      _frameClock.value = DateTime.now();
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _frameClock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: Row(
              children: [
                Icon(Icons.sports_esports, color: theme.colorScheme.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Live Game Preview',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Text(widget.status.label),
              ],
            ),
          ),
          const SizedBox(height: 12),
          AspectRatio(
            aspectRatio: 16 / 9,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final size = constraints.biggest;
                if (size.width.isFinite &&
                    size.height.isFinite &&
                    size.width > 0 &&
                    size.height > 0) {
                  _previewSize = size;
                }

                return Stack(
                  children: [
                    Positioned.fill(
                      child: CustomPaint(
                        painter: _GameShellPainter(
                          trailPoints: widget.trailPoints,
                          frameClock: _frameClock,
                          lastSlash: widget.lastSlash,
                          targetDirection: widget.targetDirection,
                          shakeController: _shakeController,
                          particles: _particles,
                        ),
                      ),
                    ),
                    Positioned(
                      left: 14,
                      top: 14,
                      child: _HudPill(
                        icon: Icons.group_outlined,
                        label: 'Players',
                        value: widget.players
                            .where(
                              (p) =>
                                  p.status == PlayerConnectionStatus.connected,
                            )
                            .length
                            .toString(),
                      ),
                    ),
                    Positioned(
                      right: 14,
                      top: 14,
                      child: _HudPill(
                        icon: Icons.timeline,
                        label: 'Trail',
                        value:
                            '${widget.trailPoints.length} ${widget.trailTransportLabel}',
                      ),
                    ),
                    Positioned(
                      left: 14,
                      right: 14,
                      bottom: 14,
                      child: Row(
                        children: [
                          Expanded(
                            child: _HudPill(
                              icon: Icons.bolt,
                              label: 'Last event',
                              value: widget.lastEventLabel,
                            ),
                          ),
                          const SizedBox(width: 10),
                          _HudPill(
                            icon: Icons.open_in_full,
                            label: 'Slash',
                            value: widget.lastSlash?.direction.name ?? '-',
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _HudPill extends StatelessWidget {
  const _HudPill({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withValues(alpha: 0.86),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: theme.colorScheme.primary),
            const SizedBox(width: 6),
            Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              value,
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GameShellPainter extends CustomPainter {
  _GameShellPainter({
    required this.trailPoints,
    required this.frameClock,
    required this.lastSlash,
    required this.targetDirection,
    required this.shakeController,
    required this.particles,
  }) : super(repaint: frameClock);

  final List<TrailRenderPoint> trailPoints;
  final ValueNotifier<DateTime> frameClock;
  final SlashEvent? lastSlash;
  final MotionDirection targetDirection;
  final ScreenShakeController shakeController;
  final List<Particle> particles;
  final _depth = const DepthTransform();

  @override
  void paint(Canvas canvas, Size size) {
    final now = frameClock.value;
    final shakeOffset = shakeController.offsetAt(now);

    if (shakeOffset != Offset.zero) {
      canvas.save();
      canvas.translate(shakeOffset.dx, shakeOffset.dy);
    }

    _paintArena(canvas, size);
    _paintTargetDirection(canvas, size);
    _paintDepthTargets(canvas, size);

    // Draw sword tip indicator first so it is underneath the active trail
    _paintSwordTipIndicator(canvas, size);

    TrailRenderer(
      points: trailPoints,
      now: now,
      sortPoints: false,
      maxPointsPerPlayer: 48,
      paintGlow: false,
    ).paint(canvas, size);

    // Paint particles!
    const ParticlePainter().paint(canvas, particles, now);

    if (shakeOffset != Offset.zero) {
      canvas.restore();
    }
  }

  void _paintArena(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final background = Paint()
      ..shader = LinearGradient(
        colors: [
          const Color(0xFF111827),
          const Color(0xFF0F172A),
          const Color(0xFF164E63).withValues(alpha: 0.78),
        ],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(rect);
    canvas.drawRect(rect, background);

    final gridPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.07)
      ..strokeWidth = 1;
    for (var i = 1; i < 5; i++) {
      final y = size.height * i / 5;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }
    for (var i = 1; i < 7; i++) {
      final x = size.width * i / 7;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
  }

  void _paintTargetDirection(Canvas canvas, Size size) {
    final center = Offset(size.width * 0.5, size.height * 0.5);
    final paint = Paint()
      ..color = Colors.cyan.withValues(alpha: 0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);

    canvas.drawCircle(center, 40, paint);

    final arrowPaint = Paint()
      ..color = Colors.cyan.withValues(alpha: 0.7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round;

    final path = Path();
    switch (targetDirection) {
      case MotionDirection.up:
        path.moveTo(center.dx, center.dy + 20);
        path.lineTo(center.dx, center.dy - 20);
        path.lineTo(center.dx - 10, center.dy - 10);
        path.moveTo(center.dx, center.dy - 20);
        path.lineTo(center.dx + 10, center.dy - 10);
      case MotionDirection.down:
        path.moveTo(center.dx, center.dy - 20);
        path.lineTo(center.dx, center.dy + 20);
        path.lineTo(center.dx - 10, center.dy + 10);
        path.moveTo(center.dx, center.dy + 20);
        path.lineTo(center.dx + 10, center.dy + 10);
      case MotionDirection.left:
        path.moveTo(center.dx + 20, center.dy);
        path.lineTo(center.dx - 20, center.dy);
        path.lineTo(center.dx - 10, center.dy - 10);
        path.moveTo(center.dx - 20, center.dy);
        path.lineTo(center.dx - 10, center.dy + 10);
      case MotionDirection.right:
        path.moveTo(center.dx - 20, center.dy);
        path.lineTo(center.dx + 20, center.dy);
        path.lineTo(center.dx + 10, center.dy - 10);
        path.moveTo(center.dx + 20, center.dy);
        path.lineTo(center.dx + 10, center.dy + 10);
      case MotionDirection.forward:
        canvas.drawCircle(
          center,
          8,
          Paint()..color = Colors.cyan.withValues(alpha: 0.8),
        );
      case MotionDirection.backward:
        canvas.drawLine(
          center - const Offset(8, 8),
          center + const Offset(8, 8),
          arrowPaint,
        );
        canvas.drawLine(
          center - const Offset(-8, 8),
          center + const Offset(-8, 8),
          arrowPaint,
        );
    }
    canvas.drawPath(path, arrowPaint);

    final textPainter = TextPainter(
      text: TextSpan(
        text: 'TARGET: ${targetDirection.name.toUpperCase()}',
        style: TextStyle(
          color: Colors.cyanAccent.withValues(alpha: 0.8),
          fontSize: 12,
          fontWeight: FontWeight.w900,
          letterSpacing: 1.5,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    textPainter.paint(
      canvas,
      Offset(center.dx - textPainter.width * 0.5, center.dy + 50),
    );
  }

  void _paintDepthTargets(Canvas canvas, Size size) {
    for (var i = 0; i < 3; i++) {
      final depth = (i + 1) / 3;
      final scale = _depth.scaleForDepth(depth);
      final opacity = _depth.opacityForDepth(depth) * 0.46;
      final center = Offset(
        size.width * (0.25 + i * 0.25),
        size.height * 0.5 + _depth.yOffsetForDepth(depth, size.height * 0.18),
      );
      final targetSize = 34 * scale;
      final paint = Paint()
        ..color = const Color(0xFF22C55E).withValues(alpha: opacity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: center,
            width: targetSize,
            height: targetSize,
          ),
          const Radius.circular(6),
        ),
        paint,
      );
    }
  }

  void _paintSwordTipIndicator(Canvas canvas, Size size) {
    final playersLastPoint = <String, TrailRenderPoint>{};
    for (final point in trailPoints) {
      final existing = playersLastPoint[point.playerId];
      if (existing == null || point.timestamp.isAfter(existing.timestamp)) {
        playersLastPoint[point.playerId] = point;
      }
    }

    final projection = const TrailProjection();
    for (final lastPoint in playersLastPoint.values) {
      if (lastPoint.strength < 3.5) {
        final pos = projection.project(
          tipX: lastPoint.tipX,
          tipY: lastPoint.tipY,
          size: size,
        );

        final circlePaint = Paint()
          ..color = const Color(0xFF4CE7FF).withValues(alpha: 0.35)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5;

        final centerPaint = Paint()
          ..color = const Color(0xFF4CE7FF).withValues(alpha: 0.6)
          ..style = PaintingStyle.fill;

        canvas.drawCircle(pos, 8.0, circlePaint);
        canvas.drawCircle(pos, 2.0, centerPaint);

        final tickPaint = Paint()
          ..color = const Color(0xFF4CE7FF).withValues(alpha: 0.4)
          ..strokeWidth = 1.0;
        canvas.drawLine(
          pos - const Offset(12, 0),
          pos - const Offset(5, 0),
          tickPaint,
        );
        canvas.drawLine(
          pos + const Offset(5, 0),
          pos + const Offset(12, 0),
          tickPaint,
        );
        canvas.drawLine(
          pos - const Offset(0, 12),
          pos - const Offset(0, 5),
          tickPaint,
        );
        canvas.drawLine(
          pos + const Offset(0, 5),
          pos + const Offset(0, 12),
          tickPaint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_GameShellPainter oldDelegate) {
    return oldDelegate.trailPoints != trailPoints ||
        oldDelegate.frameClock != frameClock ||
        oldDelegate.lastSlash != lastSlash ||
        oldDelegate.targetDirection != targetDirection ||
        oldDelegate.shakeController != shakeController ||
        oldDelegate.particles != particles;
  }
}
