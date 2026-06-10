import 'dart:math' as math;

class BasketballCourt {
  const BasketballCourt._();

  static const double releaseZ = 0.0;
  static const double hoopZ = 1.0;
  static const double backboardZ = 1.08;

  static const double releaseHeight = 0.13;
  static const double rimHeight = 0.38;
  static const double rimHalfWidth = 0.28;
  static const double rimDepth = 0.055;
  static const double rimHeightTolerance = 0.07;
  static const double rimCollisionHeight = 0.085;
  static const double rimPostRadius = 0.035;
  static const double ballCourtRadius = 0.055;

  static const double backboardHalfWidth = 0.56;
  static const double backboardBottomHeight = 0.30;
  static const double backboardTopHeight = 0.76;
}

class BasketballCourtPoint {
  const BasketballCourtPoint({
    required this.x,
    required this.y,
    required this.z,
  });

  final double x;
  final double y;
  final double z;

  BasketballCourtPoint translate({
    double dx = 0,
    double dy = 0,
    double dz = 0,
  }) {
    return BasketballCourtPoint(x: x + dx, y: y + dy, z: z + dz);
  }

  static BasketballCourtPoint lerp(
    BasketballCourtPoint a,
    BasketballCourtPoint b,
    double t,
  ) {
    final safeT = t.clamp(0.0, 1.0).toDouble();
    return BasketballCourtPoint(
      x: _lerp(a.x, b.x, safeT),
      y: _lerp(a.y, b.y, safeT),
      z: _lerp(a.z, b.z, safeT),
    );
  }

  double distance2DTo(BasketballCourtPoint other) {
    final dx = x - other.x;
    final dy = y - other.y;
    return math.sqrt(dx * dx + dy * dy);
  }

  static double _lerp(double a, double b, double t) => a + (b - a) * t;
}

class BasketballCourtVelocity {
  const BasketballCourtVelocity({
    required this.x,
    required this.y,
    required this.z,
  });

  final double x;
  final double y;
  final double z;

  BasketballCourtVelocity translate({
    double dx = 0,
    double dy = 0,
    double dz = 0,
  }) {
    return BasketballCourtVelocity(x: x + dx, y: y + dy, z: z + dz);
  }

  BasketballCourtVelocity scale({
    double xScale = 1,
    double yScale = 1,
    double zScale = 1,
  }) {
    return BasketballCourtVelocity(x: x * xScale, y: y * yScale, z: z * zScale);
  }
}
