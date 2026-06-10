import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../../shared/models/motion_event.dart';
import '../../shared/visual/depth_transform.dart';
import '../../shared/visual/particle_system.dart';
import '../../shared/visual/screen_shake_controller.dart';
import '../../shared/visual/trail_renderer.dart';
import 'saber_target.dart';
import 'saber_visual_style.dart';

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
    _paintHitZone(canvas, size, now);
    _paintTargets(canvas, size, now);
    _paintSwordTipIndicator(canvas, size);

    TrailRenderer(
      points: trailPoints,
      now: now,
      sortPoints: false,
      maxPointsPerPlayer: 56,
      paintGlow: true,
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
          const Color(0xFF030712),
          const Color(0xFF111827),
          const Color(0xFF052E2B),
        ],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(rect);
    canvas.drawRect(rect, background);

    final horizonY = size.height * 0.34;
    final centerX = size.width * 0.5;

    final gridPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.04)
      ..strokeWidth = 1;

    for (var i = 0; i <= 6; i++) {
      final t = i / 6.0;
      final y = horizonY + math.pow(t, 1.75) * (size.height - horizonY);
      gridPaint.color = Colors.white.withValues(alpha: 0.03 + t * 0.07);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    final railPaint = Paint()
      ..color = const Color(0xFF22D3EE).withValues(alpha: 0.12)
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;

    for (final lane in [-1.3, -0.75, -0.35, 0.0, 0.35, 0.75, 1.3]) {
      final start = Offset(centerX + lane * size.width * 0.035, horizonY);
      final end = Offset(centerX + lane * size.width * 0.38, size.height);
      canvas.drawLine(start, end, railPaint);
    }

    final horizonPaint = Paint()
      ..color = const Color(0xFFFF4EBD).withValues(alpha: 0.15)
      ..strokeWidth = 1.5
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);
    canvas.drawLine(
      Offset(size.width * 0.12, horizonY),
      Offset(size.width * 0.88, horizonY),
      horizonPaint,
    );
  }

  void _paintAimingLanes(Canvas canvas, Size size) {
    final centerX = size.width * 0.5;
    final horizonY = size.height * 0.34;
    final lanePaint = Paint()
      ..color = Colors.cyanAccent.withValues(alpha: 0.09)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    for (final lane in [-1.0, -0.5, 0.5, 1.0]) {
      final start = Offset(centerX + lane * (size.width * 0.045), horizonY);
      final end = Offset(centerX + lane * (size.width * 0.28), size.height);
      canvas.drawLine(start, end, lanePaint);
    }
  }

  void _paintHitZone(Canvas canvas, Size size, DateTime now) {
    final center = Offset(size.width * 0.5, size.height * 0.57);
    final rect = Rect.fromCenter(
      center: center,
      width: size.width * 0.5,
      height: size.height * 0.38,
    );
    final rrect = RRect.fromRectAndRadius(
      rect,
      Radius.circular(size.shortestSide * 0.025),
    );

    final zonePaint = Paint()
      ..color = const Color(0xFF22D3EE).withValues(alpha: 0.14)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);
    canvas.drawRRect(rrect, zonePaint);

    final tickPaint = Paint()
      ..color = const Color(0xFFFFF7AD).withValues(alpha: 0.28)
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;
    final tick = size.shortestSide * 0.035;
    for (final corner in [
      rect.topLeft,
      rect.topRight,
      rect.bottomLeft,
      rect.bottomRight,
    ]) {
      final sx = corner.dx < center.dx ? 1.0 : -1.0;
      final sy = corner.dy < center.dy ? 1.0 : -1.0;
      canvas.drawLine(corner, corner + Offset(tick * sx, 0), tickPaint);
      canvas.drawLine(corner, corner + Offset(0, tick * sy), tickPaint);
    }

    final scanProgress = (now.millisecondsSinceEpoch % 1300) / 1300.0;
    final scanY = rect.top + rect.height * scanProgress;
    final scanPaint = Paint()
      ..color = const Color(0xFFFF4EBD).withValues(alpha: 0.18)
      ..strokeWidth = 1
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    canvas.drawLine(
      Offset(rect.left + 8, scanY),
      Offset(rect.right - 8, scanY),
      scanPaint,
    );
  }

  void _paintTargets(Canvas canvas, Size size, DateTime now) {
    final centerX = size.width * 0.5;
    final centerY = size.height * 0.5;
    final pulse = math.sin(now.millisecondsSinceEpoch / 180.0) * 0.5 + 0.5;

    for (final target in targets) {
      final scale = _depth.scaleForDepth(target.depth);
      final opacity = _depth.opacityForDepth(target.depth);
      final center = Offset(
        centerX + target.lane * (size.width * 0.22) * scale,
        centerY +
            target.row * (size.height * 0.18) * scale +
            _depth.yOffsetForDepth(target.depth, size.height * 0.18),
      );

      final boxSize = 44.0 * scale * _statusScaleFor(target);
      final targetOpacity = opacity * _statusOpacityFor(target);

      final Color baseColor = saberColorForDirection(target.direction);

      if (target.isMissed) {
        _paintMissedTarget(
          canvas: canvas,
          center: center,
          boxSize: boxSize,
          scale: scale,
          opacity: targetOpacity,
          progress: target.missProgress,
        );
      } else if (!target.isCut) {
        final approach = target.depth.clamp(0.0, 1.0);
        final hitGlow = _smoothStep(0.68, 0.98, approach);

        final rect = Rect.fromCenter(
          center: center,
          width: boxSize,
          height: boxSize,
        );
        final rrect = RRect.fromRectAndRadius(
          rect,
          Radius.circular(8.0 * scale),
        );

        if (hitGlow > 0.01) {
          final glowPaint = Paint()
            ..color = baseColor.withValues(
              alpha: (0.18 + pulse * 0.08) * hitGlow * targetOpacity,
            )
            ..style = PaintingStyle.stroke
            ..strokeWidth = 5.0 * scale
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, 8.0 * scale);
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              rect.inflate(5.0 * scale * hitGlow),
              Radius.circular(12.0 * scale),
            ),
            glowPaint,
          );
        }

        final fillPaint = Paint()
          ..shader = LinearGradient(
            colors: [
              const Color(0xFF111827).withValues(alpha: targetOpacity * 0.88),
              baseColor.withValues(alpha: targetOpacity * 0.18),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ).createShader(rect)
          ..style = PaintingStyle.fill;

        final borderPaint = Paint()
          ..color = baseColor.withValues(alpha: targetOpacity * 0.9)
          ..style = PaintingStyle.stroke
          ..strokeWidth = (2.4 + hitGlow * 1.2) * scale
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, 1.8 * scale);

        canvas.drawRRect(rrect, fillPaint);
        canvas.drawRRect(rrect, borderPaint);

        _drawTargetCorners(canvas, rect, baseColor, targetOpacity, scale);
        _drawDirectionArrow(
          canvas,
          center,
          boxSize * 0.5,
          target.direction,
          baseColor.withValues(alpha: targetOpacity),
          scale,
        );
      } else {
        final double separationDistance = target.cutProgress * 36.0 * scale;
        final Offset separationVector =
            Offset(
              math.cos(target.cutAngle + math.pi / 2),
              math.sin(target.cutAngle + math.pi / 2),
            ) *
            separationDistance;

        final opacityCut = math
            .pow(1.0 - target.cutProgress, 1.4)
            .clamp(0.0, 1.0)
            .toDouble();

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

        final cutPaint = Paint()
          ..color = baseColor.withValues(alpha: opacityCut * 0.85)
          ..strokeWidth = 2.5 * scale
          ..strokeCap = StrokeCap.round
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, 4 * scale);
        final cutVector = Offset(
          math.cos(target.cutAngle),
          math.sin(target.cutAngle),
        );
        canvas.drawLine(
          center - cutVector * boxSize * 0.72,
          center + cutVector * boxSize * 0.72,
          cutPaint,
        );
      }
    }
  }

  double _statusOpacityFor(SaberTarget target) {
    if (!target.isMissed) {
      return 1.0;
    }
    return math.pow(1.0 - target.missProgress, 1.25).clamp(0.0, 1.0).toDouble();
  }

  double _statusScaleFor(SaberTarget target) {
    if (!target.isMissed) {
      return 1.0;
    }
    final pop = math.sin(target.missProgress * math.pi) * 0.18;
    return 1.0 + pop - target.missProgress * 0.1;
  }

  void _paintMissedTarget({
    required Canvas canvas,
    required Offset center,
    required double boxSize,
    required double scale,
    required double opacity,
    required double progress,
  }) {
    final rect = Rect.fromCenter(
      center: center,
      width: boxSize,
      height: boxSize,
    );
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(8.0 * scale));

    final fillPaint = Paint()
      ..color = const Color(0xFF450A0A).withValues(alpha: opacity * 0.34)
      ..style = PaintingStyle.fill;
    final borderPaint = Paint()
      ..color = Colors.redAccent.withValues(alpha: opacity * 0.75)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4 * scale
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, 2.5 * scale);

    canvas.drawRRect(rrect, fillPaint);
    canvas.drawRRect(rrect, borderPaint);

    final ringPaint = Paint()
      ..color = Colors.redAccent.withValues(alpha: opacity * 0.28)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0 * scale
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, 5 * scale);
    canvas.drawCircle(center, boxSize * (0.55 + progress * 0.45), ringPaint);

    final xPaint = Paint()
      ..color = Colors.redAccent.withValues(alpha: opacity)
      ..strokeWidth = 4.0 * scale
      ..strokeCap = StrokeCap.round;
    final offset = boxSize * 0.28;
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
  }

  void _drawTargetCorners(
    Canvas canvas,
    Rect rect,
    Color color,
    double opacity,
    double scale,
  ) {
    final paint = Paint()
      ..color = color.withValues(alpha: opacity * 0.55)
      ..strokeWidth = 1.4 * scale
      ..strokeCap = StrokeCap.round;
    final tick = rect.width * 0.17;

    for (final corner in [
      rect.topLeft,
      rect.topRight,
      rect.bottomLeft,
      rect.bottomRight,
    ]) {
      final sx = corner.dx < rect.center.dx ? 1.0 : -1.0;
      final sy = corner.dy < rect.center.dy ? 1.0 : -1.0;
      canvas.drawLine(corner, corner + Offset(tick * sx, 0), paint);
      canvas.drawLine(corner, corner + Offset(0, tick * sy), paint);
    }
  }

  double _smoothStep(double edge0, double edge1, double value) {
    final t = ((value - edge0) / (edge1 - edge0)).clamp(0.0, 1.0);
    return t * t * (3.0 - 2.0 * t);
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
