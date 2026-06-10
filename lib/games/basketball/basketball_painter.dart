import 'package:flutter/material.dart';

import 'basketball_court_space.dart';
import 'basketball_game_state.dart';
import 'basketball_physics.dart';
import 'basketball_projection.dart';

class BasketballPainter extends CustomPainter {
  const BasketballPainter({required this.state, required Listenable repaint})
    : super(repaint: repaint);

  final BasketballGameState state;

  @override
  void paint(Canvas canvas, Size size) {
    final ball = state.currentBall;
    final hoop = state.currentHoop;
    final projector = BasketballProjector(size);
    final ballBehindFrontRim = _ballBehindFrontRim(ball);

    _drawBackground(canvas, size, projector);
    _drawHoopBack(canvas, hoop);
    _drawBallShadow(canvas, ball, projector);

    if (ballBehindFrontRim) {
      _drawTrail(canvas, ball, projector);
      _drawBall(canvas, ball, projector, size);
      _drawHoopFront(canvas, hoop);
    } else {
      _drawHoopFront(canvas, hoop);
      _drawTrail(canvas, ball, projector);
      _drawBall(canvas, ball, projector, size);
    }
  }

  bool _ballBehindFrontRim(BasketballBall? ball) {
    if (ball == null) {
      return false;
    }
    final nearHoopPlane = ball.courtPosition.z >= BasketballCourt.hoopZ - 0.035;
    final inRimHeightBand =
        ball.courtPosition.y <= BasketballCourt.rimHeight + 0.13;
    return nearHoopPlane && inRimHeightBand && !ball.isRising;
  }

  void _drawBackground(
    Canvas canvas,
    Size size,
    BasketballProjector projector,
  ) {
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

    final lanePaint = Paint()
      ..color = const Color(0xFFE5E7EB)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    final nearLeft = projector.projectFloor(-0.46, 0);
    final nearRight = projector.projectFloor(0.46, 0);
    final farLeft = projector.projectFloor(-0.28, BasketballCourt.hoopZ);
    final farRight = projector.projectFloor(0.28, BasketballCourt.hoopZ);
    final lane = Path()
      ..moveTo(nearLeft.dx, nearLeft.dy)
      ..lineTo(farLeft.dx, farLeft.dy)
      ..lineTo(farRight.dx, farRight.dy)
      ..lineTo(nearRight.dx, nearRight.dy);
    canvas.drawPath(lane, lanePaint);
  }

  void _drawHoopBack(Canvas canvas, BasketballHoop hoop) {
    final scale = (hoop.rimWidth / 80).clamp(0.65, 1.8).toDouble();
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

    final backNetPaint = Paint()
      ..color = const Color(0xFFD4D4D8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4 * scale;
    canvas.drawLine(
      hoop.leftRimCenter.translate(4 * scale, 3 * scale),
      hoop.rimCenter.translate(-hoop.rimWidth * 0.18, 18 * scale),
      backNetPaint,
    );
    canvas.drawLine(
      hoop.rightRimCenter.translate(-4 * scale, 3 * scale),
      hoop.rimCenter.translate(hoop.rimWidth * 0.18, 18 * scale),
      backNetPaint,
    );
  }

  void _drawHoopFront(Canvas canvas, BasketballHoop hoop) {
    final scale = (hoop.rimWidth / 80).clamp(0.65, 1.8).toDouble();
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

  void _drawBallShadow(
    Canvas canvas,
    BasketballBall? ball,
    BasketballProjector projector,
  ) {
    if (ball == null) {
      return;
    }
    final projected = projector.projectBall(
      ball.courtPosition,
      baseRadius: ball.radius,
    );
    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: projected.shadowOpacity)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    canvas.drawOval(
      Rect.fromCenter(
        center: projected.shadowCenter,
        width: projected.radius * 2.2 * projected.shadowScale,
        height: projected.radius * 0.48 * projected.shadowScale,
      ),
      shadowPaint,
    );
  }

  void _drawTrail(
    Canvas canvas,
    BasketballBall? ball,
    BasketballProjector projector,
  ) {
    final trail = ball?.trail;
    if (trail == null || trail.length < 2) {
      return;
    }
    for (var i = 1; i < trail.length; i++) {
      final t = i / trail.length;
      final start = projector.projectPoint(trail[i - 1]);
      final end = projector.projectPoint(trail[i]);
      final paint = Paint()
        ..color = const Color(0xFFF97316).withValues(alpha: 0.04 + t * 0.14)
        ..strokeWidth = 1.2 + t * 2.0
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(start, end, paint);
    }
  }

  void _drawBall(
    Canvas canvas,
    BasketballBall? ball,
    BasketballProjector projector,
    Size size,
  ) {
    final projected = ball == null
        ? projector.projectBall(
            const BasketballCourtPoint(
              x: 0,
              y: BasketballCourt.releaseHeight,
              z: BasketballCourt.releaseZ,
            ),
            baseRadius: 24 * BasketballProjector.scaleForArena(size),
          )
        : projector.projectBall(ball.courtPosition, baseRadius: ball.radius);

    final painter = TextPainter(
      text: TextSpan(
        text: '\u{1F3C0}',
        style: TextStyle(fontSize: projected.radius * 2.05),
      ),
      textDirection: TextDirection.ltr,
    );
    painter.layout();
    painter.paint(
      canvas,
      projected.center - Offset(painter.width / 2, painter.height / 2),
    );
  }

  @override
  bool shouldRepaint(covariant BasketballPainter oldDelegate) {
    return oldDelegate.state != state;
  }
}
