import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/motion_trail_sample.dart';

class TrailRenderPoint {
  const TrailRenderPoint({
    required this.playerId,
    required this.tipX,
    required this.tipY,
    required this.strength,
    required this.timestamp,
  });

  final String playerId;
  final double tipX;
  final double tipY;
  final double strength;
  final DateTime timestamp;
}

class TrailProjection {
  const TrailProjection();

  Offset project({
    required double tipX,
    required double tipY,
    required Size size,
  }) {
    final halfWidth = size.width * 0.5;
    final halfHeight = size.height * 0.5;
    return Offset(
      halfWidth + tipX.clamp(-1.3, 1.3) * halfWidth * 0.72,
      halfHeight - tipY.clamp(-1.3, 1.3) * halfHeight * 0.72,
    );
  }

  TrailRenderPoint fromSample({
    required String playerId,
    required MotionTrailSample sample,
    required DateTime referenceTimestamp,
  }) {
    return TrailRenderPoint(
      playerId: playerId,
      tipX: sample.tipX,
      tipY: sample.tipY,
      strength: sample.strength,
      timestamp: referenceTimestamp.add(Duration(milliseconds: sample.tMs)),
    );
  }
}

class TrailRenderer extends CustomPainter {
  TrailRenderer({
    required this.points,
    required this.now,
    this.fadeDuration = const Duration(milliseconds: 700),
    this.projection = const TrailProjection(),
    this.baseColor = const Color(0xFF4CE7FF),
    this.sortPoints = true,
    this.maxPointsPerPlayer = 96,
    this.paintGlow = true,
  });

  static const MaskFilter _trailGlowMask = MaskFilter.blur(BlurStyle.normal, 7);

  final List<TrailRenderPoint> points;
  final DateTime now;
  final Duration fadeDuration;
  final TrailProjection projection;
  final Color baseColor;
  final bool sortPoints;
  final int maxPointsPerPlayer;
  final bool paintGlow;

  List<TrailRenderPoint> interpolate(
    List<TrailRenderPoint> input, {
    int stepMs = 24,
    int maxInsertedPointsPerSegment = 2,
  }) {
    if (input.length < 3) {
      return input;
    }
    final List<TrailRenderPoint> result = [];

    for (var i = 0; i < input.length - 1; i++) {
      final p0 = input[i == 0 ? 0 : i - 1];
      final p1 = input[i];
      final p2 = input[i + 1];
      final p3 = input[i + 2 >= input.length ? input.length - 1 : i + 2];

      result.add(p1);

      final duration = p2.timestamp.difference(p1.timestamp).inMilliseconds;
      if (duration > stepMs) {
        final int steps = (duration / stepMs).round().clamp(
          2,
          maxInsertedPointsPerSegment + 1,
        );
        for (var step = 1; step < steps; step++) {
          final double t = step / steps.toDouble();
          final double t2 = t * t;
          final double t3 = t2 * t;

          final double f0 = -0.5 * t3 + t2 - 0.5 * t;
          final double f1 = 1.5 * t3 - 2.5 * t2 + 1.0;
          final double f2 = -1.5 * t3 + 2.0 * t2 + 0.5 * t;
          final double f3 = 0.5 * t3 - 0.5 * t2;

          final double x =
              p0.tipX * f0 + p1.tipX * f1 + p2.tipX * f2 + p3.tipX * f3;
          final double y =
              p0.tipY * f0 + p1.tipY * f1 + p2.tipY * f2 + p3.tipY * f3;

          final double strength = p1.strength + (p2.strength - p1.strength) * t;
          final DateTime timestamp = p1.timestamp.add(
            Duration(milliseconds: (duration * t).round()),
          );

          result.add(
            TrailRenderPoint(
              playerId: p1.playerId,
              tipX: x,
              tipY: y,
              strength: strength,
              timestamp: timestamp,
            ),
          );
        }
      }
    }
    result.add(input.last);
    return result;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final grouped = <String, List<TrailRenderPoint>>{};
    for (final point in points) {
      if (_ageRatio(point) <= 1) {
        grouped.putIfAbsent(point.playerId, () => []).add(point);
      }
    }

    for (final playerPoints in grouped.values) {
      if (sortPoints) {
        playerPoints.sort((a, b) => a.timestamp.compareTo(b.timestamp));
      }
      final start = math.max(0, playerPoints.length - maxPointsPerPlayer);
      final visiblePoints = start == 0
          ? playerPoints
          : playerPoints.sublist(start);
      final smoothed = interpolate(visiblePoints);
      _paintTrail(canvas, size, smoothed);
    }
  }

  void _paintTrail(Canvas canvas, Size size, List<TrailRenderPoint> trail) {
    if (trail.length < 2) {
      return;
    }

    final glowPaint = Paint()
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke
      ..maskFilter = _trailGlowMask;
    final corePaint = Paint()
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final first = trail.first;
    var previousOffset = projection.project(
      tipX: first.tipX,
      tipY: first.tipY,
      size: size,
    );

    for (var i = 1; i < trail.length; i++) {
      final current = trail[i];
      final currentOffset = projection.project(
        tipX: current.tipX,
        tipY: current.tipY,
        size: size,
      );
      final opacity = (1 - _ageRatio(current)).clamp(0.0, 1.0);
      final width = 2.5 + math.min(current.strength, 18) * 0.38;

      if (paintGlow && opacity > 0.08) {
        glowPaint
          ..color = baseColor.withValues(alpha: opacity * 0.22)
          ..strokeWidth = width * 2.7;
        canvas.drawLine(previousOffset, currentOffset, glowPaint);
      }
      corePaint
        ..color = Colors.white.withValues(alpha: opacity * 0.9)
        ..strokeWidth = width;
      canvas.drawLine(previousOffset, currentOffset, corePaint);

      previousOffset = currentOffset;
    }
  }

  double _ageRatio(TrailRenderPoint point) {
    return now.difference(point.timestamp).inMilliseconds /
        fadeDuration.inMilliseconds;
  }

  @override
  bool shouldRepaint(TrailRenderer oldDelegate) {
    return oldDelegate.points != points || oldDelegate.now != now;
  }
}
