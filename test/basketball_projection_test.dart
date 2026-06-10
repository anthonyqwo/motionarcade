import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:motionarcade/games/basketball/basketball_court_space.dart';
import 'package:motionarcade/games/basketball/basketball_projection.dart';

void main() {
  group('BasketballProjector', () {
    const size = Size(800, 450);
    const projector = BasketballProjector(size);

    test('farther court points move toward the hoop and shrink the ball', () {
      const near = BasketballCourtPoint(x: 0.7, y: 0.2, z: 0);
      const far = BasketballCourtPoint(x: 0.7, y: 0.2, z: 1);

      final nearBall = projector.projectBall(near, baseRadius: 24);
      final farBall = projector.projectBall(far, baseRadius: 24);

      expect(
        (farBall.center.dx - size.width / 2).abs(),
        lessThan((nearBall.center.dx - size.width / 2).abs()),
      );
      expect(farBall.center.dy, lessThan(nearBall.center.dy));
      expect(farBall.radius, lessThan(nearBall.radius));
    });

    test('shadow stays on the floor projection while ball height changes', () {
      const low = BasketballCourtPoint(x: -0.2, y: 0.1, z: 0.55);
      const high = BasketballCourtPoint(x: -0.2, y: 0.62, z: 0.55);

      final lowBall = projector.projectBall(low, baseRadius: 24);
      final highBall = projector.projectBall(high, baseRadius: 24);

      expect(highBall.shadowCenter, lowBall.shadowCenter);
      expect(highBall.center.dy, lessThan(lowBall.center.dy));
      expect(highBall.shadowScale, lessThan(lowBall.shadowScale));
      expect(highBall.shadowOpacity, lessThan(lowBall.shadowOpacity));
    });

    test('hoop projection lands above its floor anchor', () {
      final rim = projector.projectPoint(
        const BasketballCourtPoint(
          x: 0,
          y: BasketballCourt.rimHeight,
          z: BasketballCourt.hoopZ,
        ),
      );
      final floor = projector.projectFloor(0, BasketballCourt.hoopZ);

      expect(rim.dy, lessThan(floor.dy));
      expect(rim.dx, floor.dx);
    });

    test('shared ball base radius projects to 80 percent of rim width', () {
      final hoopWidth =
          BasketballCourt.rimHalfWidth *
          projector.courtHalfWidthAtDepth(BasketballCourt.hoopZ) *
          2;
      final projected = projector.projectBall(
        const BasketballCourtPoint(
          x: 0,
          y: BasketballCourt.rimHeight,
          z: BasketballCourt.hoopZ,
        ),
        baseRadius: projector.ballBaseRadiusForHoopRatio(),
      );

      expect(projected.radius * 2, closeTo(hoopWidth * 0.8, 0.5));
    });
  });
}
