import 'dart:ui';

import 'basketball_court_space.dart';

class ProjectedBasketball {
  const ProjectedBasketball({
    required this.center,
    required this.shadowCenter,
    required this.radius,
    required this.shadowScale,
    required this.shadowOpacity,
    required this.depth,
  });

  final Offset center;
  final Offset shadowCenter;
  final double radius;
  final double shadowScale;
  final double shadowOpacity;
  final double depth;
}

class BasketballProjector {
  const BasketballProjector(this.size);

  static const double defaultBallToRimDiameterRatio = 0.8;

  final Size size;

  Offset projectPoint(BasketballCourtPoint point) {
    final floor = projectFloor(point.x, point.z);
    final vertical = verticalScaleForDepth(point.z);
    return Offset(floor.dx, floor.dy - point.y * vertical);
  }

  Offset projectFloor(double x, double z) {
    final depth = depthT(z);
    final eased = _easeOut(depth);
    final floorY = _lerp(size.height * 0.88, size.height * 0.45, eased);
    final halfWidth = courtHalfWidthAtDepth(z);
    return Offset(size.width / 2 + x * halfWidth, floorY);
  }

  ProjectedBasketball projectBall(
    BasketballCourtPoint point, {
    required double baseRadius,
  }) {
    final center = projectPoint(point);
    final shadowCenter = projectFloor(point.x, point.z);
    final heightT = (point.y / 0.66).clamp(0.0, 1.0).toDouble();
    return ProjectedBasketball(
      center: center,
      shadowCenter: shadowCenter,
      radius: baseRadius * ballScaleForDepth(point.z),
      shadowScale: _lerp(1.0, 0.55, heightT),
      shadowOpacity: _lerp(0.22, 0.08, heightT),
      depth: point.z,
    );
  }

  double ballScaleForDepth(double z) {
    return _lerp(1.18, 0.88, depthT(z));
  }

  double ballBaseRadiusForHoopRatio([
    double ratio = defaultBallToRimDiameterRatio,
  ]) {
    final hoopWidth =
        BasketballCourt.rimHalfWidth *
        courtHalfWidthAtDepth(BasketballCourt.hoopZ) *
        2;
    return (hoopWidth * ratio / 2) / ballScaleForDepth(BasketballCourt.hoopZ);
  }

  double hoopScale() {
    final arenaScale = scaleForArena(size);
    return arenaScale * _lerp(1.0, 0.94, depthT(BasketballCourt.hoopZ));
  }

  double courtHalfWidthAtDepth(double z) {
    return _lerp(size.width * 0.43, size.width * 0.18, depthT(z));
  }

  double verticalScaleForDepth(double z) {
    return _lerp(size.height * 0.54, size.height * 0.48, depthT(z));
  }

  double depthT(double z) {
    return z.clamp(0.0, 1.0).toDouble();
  }

  static double scaleForArena(Size size) {
    if (size.width <= 0 || size.height <= 0) {
      return 1;
    }
    return (size.shortestSide / 450).clamp(0.7, 1.45).toDouble();
  }

  static double _easeOut(double t) {
    final inv = 1 - t;
    return 1 - inv * inv * inv;
  }

  static double _lerp(double a, double b, double t) => a + (b - a) * t;
}
