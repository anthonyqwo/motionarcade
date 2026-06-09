import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../../shared/models/motion_event.dart';
import '../../shared/visual/depth_transform.dart';
import '../../shared/visual/particle_system.dart';
import '../../shared/visual/screen_shake_controller.dart';
import '../../shared/visual/trail_renderer.dart';
import 'saber_target.dart';

class SaberPainter extends CustomPainter {
  SaberPainter({
    required this.targets,
    required this.trailPoints,
    required this.frameClock,
    required this.lastSlash,
    required this.shakeController,
    required this.particles,
  }) : super(repaint: frameClock);

  final List<SaberTarget> targets;
  final List<TrailRenderPoint> trailPoints;
  final ValueNotifier<DateTime> frameClock;
  final SlashEvent? lastSlash;
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
    _paintAimingLanes(canvas, size);
    _paintTargets(canvas, size);
    _paintSwordTipIndicator(canvas, size);

    TrailRenderer(
      points: trailPoints,
      now: now,
      sortPoints: false,
      maxPointsPerPlayer: 48,
      paintGlow: false,
    ).paint(canvas, size);

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
          const Color(0xFF0F172A),
          const Color(0xFF030712),
          const Color(0xFF082F49).withValues(alpha: 0.8),
        ],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(rect);
    canvas.drawRect(rect, background);

    final gridPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.05)
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

  void _paintAimingLanes(Canvas canvas, Size size) {
    final centerX = size.width * 0.5;
    final centerY = size.height * 0.5;
    final lanePaint = Paint()
      ..color = Colors.cyan.withValues(alpha: 0.08)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    // Draw horizontal reference lines representing Left/Center/Right lanes converging to the horizon
    for (final lane in [-1.0, 0.0, 1.0]) {
      final start = Offset(centerX + lane * (size.width * 0.05), centerY);
      final end = Offset(centerX + lane * (size.width * 0.26), size.height);
      canvas.drawLine(start, end, lanePaint);
    }
  }

  void _paintTargets(Canvas canvas, Size size) {
    final centerX = size.width * 0.5;
    final centerY = size.height * 0.5;

    for (final target in targets) {
      final scale = _depth.scaleForDepth(target.depth);
      final opacity = _depth.opacityForDepth(target.depth);
      final center = Offset(
        centerX + target.lane * (size.width * 0.22) * scale,
        centerY + _depth.yOffsetForDepth(target.depth, size.height * 0.18),
      );

      final boxSize = 44.0 * scale;

      // Color mapping based on direction
      final Color baseColor = _colorForDirection(target.direction);

      if (!target.isCut) {
        // Draw uncut target cube
        final isMissed = target.status == SaberTargetStatus.missed;
        final borderPaint = Paint()
          ..color = isMissed
              ? Colors.redAccent.withValues(alpha: opacity * 0.6)
              : baseColor.withValues(alpha: opacity * 0.9)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3.0 * scale
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, 2.0 * scale);

        final fillPaint = Paint()
          ..color = isMissed
              ? const Color(0x773F3F46)
              : const Color(0xBB1E293B).withValues(alpha: opacity * 0.73)
          ..style = PaintingStyle.fill;

        final rect = Rect.fromCenter(
          center: center,
          width: boxSize,
          height: boxSize,
        );
        final rrect = RRect.fromRectAndRadius(
          rect,
          Radius.circular(8.0 * scale),
        );

        canvas.drawRRect(rrect, fillPaint);
        canvas.drawRRect(rrect, borderPaint);

        if (isMissed) {
          // Draw an X inside
          final xPaint = Paint()
            ..color = Colors.redAccent.withValues(alpha: opacity)
            ..strokeWidth = 3.5 * scale
            ..strokeCap = StrokeCap.round;
          final offset = boxSize * 0.25;
          canvas.drawLine(
            center - Offset(offset, offset),
            center + Offset(offset, offset),
            xPaint,
          );
          canvas.drawLine(
            center - Offset(-offset, offset),
            center + Offset(-offset, offset),
            xPaint,
          );
        } else {
          // Draw directional arrow inside
          _drawDirectionArrow(
            canvas,
            center,
            boxSize * 0.5,
            target.direction,
            baseColor.withValues(alpha: opacity),
            scale,
          );
        }
      } else {
        // Draw split halves animation
        final double separationDistance = target.cutProgress * 28.0 * scale;
        final Offset separationVector =
            Offset(
              math.cos(target.cutAngle + math.pi / 2),
              math.sin(target.cutAngle + math.pi / 2),
            ) *
            separationDistance;

        final opacityCut = (1.0 - target.cutProgress).clamp(0.0, 1.0);

        final fillPaint = Paint()
          ..color = const Color(0xBB1E293B).withValues(alpha: opacityCut * 0.73)
          ..style = PaintingStyle.fill;

        final borderPaint = Paint()
          ..color = baseColor.withValues(alpha: opacityCut * 0.8)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0 * scale;

        final double spinAngle = target.cutProgress * 0.35;

        // Draw left/top piece
        canvas.save();
        canvas.translate(
          center.dx - separationVector.dx,
          center.dy - separationVector.dy,
        );
        canvas.rotate(-spinAngle);
        final pathLeft = _getPathForHalf(boxSize, true, target.cutAngle);
        canvas.drawPath(pathLeft, fillPaint);
        canvas.drawPath(pathLeft, borderPaint);
        canvas.restore();

        // Draw right/bottom piece
        canvas.save();
        canvas.translate(
          center.dx + separationVector.dx,
          center.dy + separationVector.dy,
        );
        canvas.rotate(spinAngle);
        final pathRight = _getPathForHalf(boxSize, false, target.cutAngle);
        canvas.drawPath(pathRight, fillPaint);
        canvas.drawPath(pathRight, borderPaint);
        canvas.restore();
      }
    }
  }

  Path _getPathForHalf(double size, bool isFirstHalf, double cutAngle) {
    final path = Path();
    final half = size / 2;

    // Check if horizontal split or vertical split
    final isHorizontal = (cutAngle - math.pi / 2).abs() < 0.1;

    if (isHorizontal) {
      if (isFirstHalf) {
        // Top half
        path.moveTo(-half, -half);
        path.lineTo(half, -half);
        path.lineTo(half, 0);
        path.lineTo(-half, 0);
      } else {
        // Bottom half
        path.moveTo(-half, 0);
        path.lineTo(half, 0);
        path.lineTo(half, half);
        path.lineTo(-half, half);
      }
    } else {
      if (isFirstHalf) {
        // Left half
        path.moveTo(-half, -half);
        path.lineTo(0, -half);
        path.lineTo(0, half);
        path.lineTo(-half, half);
      } else {
        // Right half
        path.moveTo(0, -half);
        path.lineTo(half, -half);
        path.lineTo(half, half);
        path.lineTo(0, half);
      }
    }
    path.close();
    return path;
  }

  void _drawDirectionArrow(
    Canvas canvas,
    Offset center,
    double arrowSize,
    MotionDirection direction,
    Color color,
    double scale,
  ) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 3.5 * scale
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final path = Path();
    final half = arrowSize * 0.5;

    switch (direction) {
      case MotionDirection.up:
        path.moveTo(center.dx, center.dy + half);
        path.lineTo(center.dx, center.dy - half);
        path.lineTo(center.dx - half * 0.6, center.dy - half * 0.2);
        path.moveTo(center.dx, center.dy - half);
        path.lineTo(center.dx + half * 0.6, center.dy - half * 0.2);
      case MotionDirection.down:
        path.moveTo(center.dx, center.dy - half);
        path.lineTo(center.dx, center.dy + half);
        path.lineTo(center.dx - half * 0.6, center.dy + half * 0.2);
        path.moveTo(center.dx, center.dy + half);
        path.lineTo(center.dx + half * 0.6, center.dy + half * 0.2);
      case MotionDirection.left:
        path.moveTo(center.dx + half, center.dy);
        path.lineTo(center.dx - half, center.dy);
        path.lineTo(center.dx - half * 0.2, center.dy - half * 0.6);
        path.moveTo(center.dx - half, center.dy);
        path.lineTo(center.dx - half * 0.2, center.dy + half * 0.6);
      case MotionDirection.right:
        path.moveTo(center.dx - half, center.dy);
        path.lineTo(center.dx + half, center.dy);
        path.lineTo(center.dx + half * 0.2, center.dy - half * 0.6);
        path.moveTo(center.dx + half, center.dy);
        path.lineTo(center.dx + half * 0.2, center.dy + half * 0.6);
      case MotionDirection.forward:
        canvas.drawCircle(center, arrowSize * 0.3, paint);
      case MotionDirection.backward:
        canvas.drawLine(
          center - Offset(half, half),
          center + Offset(half, half),
          paint,
        );
        canvas.drawLine(
          center - Offset(-half, half),
          center + Offset(-half, half),
          paint,
        );
    }
    canvas.drawPath(path, paint);
  }

  Color _colorForDirection(MotionDirection direction) {
    switch (direction) {
      case MotionDirection.up || MotionDirection.down:
        return const Color(0xFF22D3EE); // Neon Cyan
      case MotionDirection.left:
        return const Color(0xFFEF4444); // Neon Red
      case MotionDirection.right:
        return const Color(0xFF3B82F6); // Neon Blue
      default:
        return Colors.white;
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
  bool shouldRepaint(SaberPainter oldDelegate) {
    return oldDelegate.targets != targets ||
        oldDelegate.trailPoints != trailPoints ||
        oldDelegate.frameClock != frameClock ||
        oldDelegate.lastSlash != lastSlash ||
        oldDelegate.shakeController != shakeController ||
        oldDelegate.particles != particles;
  }
}
