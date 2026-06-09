import 'package:flutter/material.dart';

import 'basketball_game_state.dart';
import 'basketball_physics.dart';

class BasketballPainter extends CustomPainter {
  const BasketballPainter({required this.state, required Listenable repaint})
    : super(repaint: repaint);

  final BasketballGameState state;

  @override
  void paint(Canvas canvas, Size size) {
    _drawBackground(canvas, size);
    _drawHoop(canvas, state.currentHoop);
    _drawTrail(canvas, state.currentBall);
    _drawBall(canvas, state.currentBall, size);
  }

  void _drawBackground(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = Colors.white);

    final floorTop = size.height * 0.86;
    final floorPaint = Paint()..color = const Color(0xFFF4F4F5);
    canvas.drawRect(
      Rect.fromLTWH(0, floorTop, size.width, size.height - floorTop),
      floorPaint,
    );

    final linePaint = Paint()
      ..color = const Color(0xFFE4E4E7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    canvas.drawLine(
      Offset(0, floorTop),
      Offset(size.width, floorTop),
      linePaint,
    );
  }

  void _drawHoop(Canvas canvas, BasketballHoop hoop) {
    final scale = (hoop.rimWidth / 74).clamp(0.65, 1.8).toDouble();
    final boardRect = Rect.fromCenter(
      center: hoop.rimCenter.translate(0, -30 * scale),
      width: 154 * scale,
      height: 92 * scale,
    );
    final innerRect = Rect.fromCenter(
      center: hoop.rimCenter.translate(0, -20 * scale),
      width: 54 * scale,
      height: 52 * scale,
    );

    final boardStroke = Paint()
      ..color = const Color(0xFFA1A1AA)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3 * scale;
    canvas.drawRect(boardRect, boardStroke);
    canvas.drawRect(innerRect, boardStroke);

    final rimPaint = Paint()
      ..color = Colors.redAccent
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.square
      ..strokeWidth = 4 * scale;
    canvas.drawLine(hoop.leftRimCenter, hoop.rightRimCenter, rimPaint);

    final netPaint = Paint()
      ..color = const Color(0xFF52525B)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2 * scale;
    canvas.drawLine(
      hoop.rimCenter.translate(-hoop.rimWidth * 0.24, 8 * scale),
      hoop.rimCenter.translate(hoop.rimWidth * 0.24, 8 * scale),
      netPaint,
    );
    canvas.drawLine(
      hoop.rimCenter.translate(-hoop.rimWidth * 0.18, 13 * scale),
      hoop.rimCenter.translate(hoop.rimWidth * 0.18, 13 * scale),
      netPaint,
    );

    final standPaint = Paint()
      ..color = const Color(0xFF71717A)
      ..style = PaintingStyle.fill;
    canvas.drawRect(
      Rect.fromCenter(
        center: hoop.rimCenter.translate(0, 20 * scale),
        width: 45 * scale,
        height: 5 * scale,
      ),
      standPaint,
    );
  }

  void _drawTrail(Canvas canvas, BasketballBall? ball) {
    final trail = ball?.trail;
    if (trail == null || trail.length < 2) {
      return;
    }
    for (var i = 1; i < trail.length; i++) {
      final t = i / trail.length;
      final paint = Paint()
        ..color = const Color(0xFFF97316).withValues(alpha: 0.05 + t * 0.18)
        ..strokeWidth = 1.5 + t * 2
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(trail[i - 1], trail[i], paint);
    }
  }

  void _drawBall(Canvas canvas, BasketballBall? ball, Size size) {
    final radius = (ball?.radius ?? 22.0) * (ball == null ? 1.15 : 1.45);
    final center = ball?.position ?? Offset(size.width / 2, size.height - 72);

    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.12)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(center.dx, size.height * 0.91),
        width: radius * 2.2,
        height: radius * 0.7,
      ),
      shadowPaint,
    );

    final painter = TextPainter(
      text: TextSpan(
        text: '🏀',
        style: TextStyle(fontSize: radius * 2.05),
      ),
      textDirection: TextDirection.ltr,
    );
    painter.layout();
    painter.paint(
      canvas,
      center - Offset(painter.width / 2, painter.height / 2),
    );
  }

  @override
  bool shouldRepaint(covariant BasketballPainter oldDelegate) {
    return oldDelegate.state != state;
  }
}
