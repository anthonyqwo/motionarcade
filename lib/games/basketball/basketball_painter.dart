import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'basketball_game_state.dart';
import 'basketball_physics.dart';

class BasketballPainter extends CustomPainter {
  const BasketballPainter({required this.state, required Listenable repaint})
    : super(repaint: repaint);

  final BasketballGameState state;

  @override
  void paint(Canvas canvas, Size size) {
    _drawCourt(canvas, size);
    _drawHoop(canvas, state.currentHoop);
    _drawTrail(canvas, state.currentBall);
    _drawBall(canvas, state.currentBall, size);
  }

  void _drawCourt(Canvas canvas, Size size) {
    final background = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF1D4ED8), Color(0xFF0F766E), Color(0xFF78350F)],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, background);

    final floorTop = size.height * 0.58;
    final floorPaint = Paint()..color = const Color(0xFFB45309);
    canvas.drawRect(
      Rect.fromLTWH(0, floorTop, size.width, size.height - floorTop),
      floorPaint,
    );

    final linePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.28)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawLine(
      Offset(0, floorTop),
      Offset(size.width, floorTop),
      linePaint,
    );
    canvas.drawArc(
      Rect.fromCenter(
        center: Offset(size.width / 2, size.height * 0.95),
        width: size.width * 0.52,
        height: size.height * 0.62,
      ),
      math.pi,
      math.pi,
      false,
      linePaint,
    );
    canvas.drawCircle(
      Offset(size.width / 2, size.height * 0.78),
      size.width * 0.08,
      linePaint,
    );
  }

  void _drawHoop(Canvas canvas, BasketballHoop hoop) {
    final boardPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.9)
      ..style = PaintingStyle.fill;
    final boardStroke = Paint()
      ..color = const Color(0xFF1F2937)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawRRect(
      RRect.fromRectAndRadius(hoop.backboardRect, const Radius.circular(2)),
      boardPaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(hoop.backboardRect, const Radius.circular(2)),
      boardStroke,
    );

    final rimPaint = Paint()
      ..color = const Color(0xFFF97316)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 5;
    final rimFill = Paint()..color = const Color(0xFFF97316);
    canvas.drawLine(hoop.leftRimCenter, hoop.rightRimCenter, rimPaint);
    canvas.drawCircle(hoop.leftRimCenter, hoop.rimRadius, rimFill);
    canvas.drawCircle(hoop.rightRimCenter, hoop.rimRadius, rimFill);

    final netPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.76)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;
    final netTopLeft = hoop.leftRimCenter.translate(5, 3);
    final netTopRight = hoop.rightRimCenter.translate(-5, 3);
    final netBottomLeft = hoop.rimCenter.translate(-hoop.rimWidth * 0.28, 38);
    final netBottomRight = hoop.rimCenter.translate(hoop.rimWidth * 0.28, 38);
    canvas.drawLine(netTopLeft, netBottomLeft, netPaint);
    canvas.drawLine(netTopRight, netBottomRight, netPaint);
    canvas.drawLine(hoop.rimCenter.translate(-10, 4), netBottomRight, netPaint);
    canvas.drawLine(hoop.rimCenter.translate(10, 4), netBottomLeft, netPaint);
    canvas.drawLine(netBottomLeft, netBottomRight, netPaint);
  }

  void _drawTrail(Canvas canvas, BasketballBall? ball) {
    final trail = ball?.trail;
    if (trail == null || trail.length < 2) {
      return;
    }
    for (var i = 1; i < trail.length; i++) {
      final t = i / trail.length;
      final paint = Paint()
        ..color = Colors.white.withValues(alpha: 0.08 + t * 0.24)
        ..strokeWidth = 2 + t * 3
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(trail[i - 1], trail[i], paint);
    }
  }

  void _drawBall(Canvas canvas, BasketballBall? ball, Size size) {
    final radius = ball?.radius ?? 14.0;
    final center = ball?.position ?? Offset(size.width / 2, size.height - 72);

    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.22)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(center.dx, size.height * 0.91),
        width: radius * 2.2,
        height: radius * 0.7,
      ),
      shadowPaint,
    );

    final ballPaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.35, -0.45),
        radius: 0.9,
        colors: const [Color(0xFFFFB86B), Color(0xFFF97316), Color(0xFF9A3412)],
      ).createShader(Rect.fromCircle(center: center, radius: radius));
    canvas.drawCircle(center, radius, ballPaint);

    final seamPaint = Paint()
      ..color = const Color(0xFF7C2D12).withValues(alpha: 0.75)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6;
    canvas.drawLine(
      center.translate(-radius * 0.78, 0),
      center.translate(radius * 0.78, 0),
      seamPaint,
    );
    canvas.drawLine(
      center.translate(0, -radius * 0.78),
      center.translate(0, radius * 0.78),
      seamPaint,
    );
    canvas.drawArc(
      Rect.fromCircle(
        center: center.translate(-radius * 0.52, 0),
        radius: radius,
      ),
      -math.pi / 2,
      math.pi,
      false,
      seamPaint,
    );
    canvas.drawArc(
      Rect.fromCircle(
        center: center.translate(radius * 0.52, 0),
        radius: radius,
      ),
      math.pi / 2,
      math.pi,
      false,
      seamPaint,
    );
  }

  @override
  bool shouldRepaint(covariant BasketballPainter oldDelegate) {
    return oldDelegate.state != state;
  }
}
