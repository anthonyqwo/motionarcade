import 'dart:math' as math;
import 'dart:ui';

import 'basketball_court_space.dart';
import 'basketball_projection.dart';

enum BasketballShotOutcome { inFlight, scored, missed }

enum BasketballMissType {
  short,
  long,
  left,
  right,
  rimOut,
  backboardOut,
  timeout,
  outOfBounds,
}

enum BasketballCollisionType { none, rim, backboard }

class BasketballDifficulty {
  const BasketballDifficulty({
    required this.hoopSpeed,
    required this.hoopAmplitude,
    required this.hitTolerance,
    required this.label,
  });

  final double hoopSpeed;
  final double hoopAmplitude;
  final double hitTolerance;
  final String label;

  static BasketballDifficulty forStreak(int streak) {
    if (streak >= 25) {
      return const BasketballDifficulty(
        hoopSpeed: 1.35,
        hoopAmplitude: 130,
        hitTolerance: 0.70,
        label: 'Expert',
      );
    }
    if (streak >= 15) {
      return const BasketballDifficulty(
        hoopSpeed: 1.0,
        hoopAmplitude: 100,
        hitTolerance: 0.76,
        label: 'Moving',
      );
    }
    if (streak >= 10) {
      return const BasketballDifficulty(
        hoopSpeed: 0.7,
        hoopAmplitude: 70,
        hitTolerance: 0.82,
        label: 'Moving',
      );
    }
    if (streak >= 5) {
      return const BasketballDifficulty(
        hoopSpeed: 0,
        hoopAmplitude: 0,
        hitTolerance: 0.88,
        label: 'Focused',
      );
    }
    return const BasketballDifficulty(
      hoopSpeed: 0,
      hoopAmplitude: 0,
      hitTolerance: 1.0,
      label: 'Warmup',
    );
  }

  double movementOffset(double elapsedSeconds) {
    if (hoopSpeed <= 0 || hoopAmplitude <= 0) {
      return 0;
    }
    return math.sin(elapsedSeconds * hoopSpeed * math.pi * 2) * hoopAmplitude;
  }
}

class BasketballBall {
  BasketballBall({
    required this.courtPosition,
    required this.courtVelocity,
    BasketballCourtPoint? previousCourtPosition,
    this.radius = 24,
    this.ageSeconds = 0,
    this.collisionCount = 0,
    this.resolved = false,
    this.lastCollision = BasketballCollisionType.none,
    List<BasketballCourtPoint>? trail,
  }) : previousCourtPosition = previousCourtPosition ?? courtPosition,
       trail = trail ?? [courtPosition];

  BasketballCourtPoint courtPosition;
  BasketballCourtPoint previousCourtPosition;
  BasketballCourtVelocity courtVelocity;
  double radius;
  double ageSeconds;
  int collisionCount;
  bool resolved;
  BasketballCollisionType lastCollision;
  final List<BasketballCourtPoint> trail;

  bool get isRising => courtVelocity.y > 0;

  void recordTrail() {
    trail.add(courtPosition);
    if (trail.length > 26) {
      trail.removeRange(0, trail.length - 26);
    }
  }
}

class BasketballHoop {
  const BasketballHoop({
    required this.courtX,
    required this.rimCenter,
    required this.rimWidth,
    required this.rimRadius,
    required this.backboardRect,
    required this.hitTolerance,
  });

  factory BasketballHoop.forArena({
    required Size arena,
    required BasketballDifficulty difficulty,
    required double elapsedSeconds,
  }) {
    final projector = BasketballProjector(arena);
    final scale = projector.hoopScale();
    final movement =
        difficulty.movementOffset(elapsedSeconds) *
        BasketballProjector.scaleForArena(arena);
    final hoopHalfWidth = projector.courtHalfWidthAtDepth(
      BasketballCourt.hoopZ,
    );
    final courtX = hoopHalfWidth <= 0
        ? 0.0
        : (movement / hoopHalfWidth).clamp(-1.05, 1.05).toDouble();
    final rimCenter = projector.projectPoint(
      BasketballCourtPoint(
        x: courtX,
        y: BasketballCourt.rimHeight,
        z: BasketballCourt.hoopZ,
      ),
    );
    final rimWidth = BasketballCourt.rimHalfWidth * hoopHalfWidth * 2;
    final boardWidth = 154.0 * scale;
    final boardHeight = 92.0 * scale;
    final boardCollisionWidth = 5.0 * scale;
    final backboardRect = Rect.fromLTWH(
      rimCenter.dx + boardWidth / 2 - boardCollisionWidth / 2,
      rimCenter.dy - 30 * scale - boardHeight / 2,
      boardCollisionWidth,
      boardHeight,
    );

    return BasketballHoop(
      courtX: courtX,
      rimCenter: rimCenter,
      rimWidth: rimWidth,
      rimRadius: 7.0 * scale,
      backboardRect: backboardRect,
      hitTolerance: difficulty.hitTolerance,
    );
  }

  final double courtX;
  final Offset rimCenter;
  final double rimWidth;
  final double rimRadius;
  final Rect backboardRect;
  final double hitTolerance;

  Offset get leftRimCenter => rimCenter.translate(-rimWidth / 2, 0);
  Offset get rightRimCenter => rimCenter.translate(rimWidth / 2, 0);
}

class BasketballStepResult {
  const BasketballStepResult({
    required this.outcome,
    this.collision = BasketballCollisionType.none,
    this.missType,
  });

  final BasketballShotOutcome outcome;
  final BasketballCollisionType collision;
  final BasketballMissType? missType;

  bool get scored => outcome == BasketballShotOutcome.scored;
  bool get missed => outcome == BasketballShotOutcome.missed;
}

class BasketballPhysics {
  const BasketballPhysics({
    this.gravityY = 4.4,
    this.rimRestitution = 0.54,
    this.rimDamping = 0.78,
    this.backboardRestitutionZ = 0.46,
    this.backboardDampingY = 0.72,
  });

  final double gravityY;
  final double rimRestitution;
  final double rimDamping;
  final double backboardRestitutionZ;
  final double backboardDampingY;

  BasketballBall launchBall({
    required Size arena,
    required double power,
    required double angle,
    required double offset,
    required double stability,
  }) {
    final rawPower = power.clamp(0.0, 1.0).toDouble();
    final mappedPower = 1 - math.pow(1 - rawPower, 1.45).toDouble();
    final normalizedAngle = ((angle.clamp(32.0, 62.0) - 32) / 30).clamp(
      0.0,
      1.0,
    );
    final angleFromCenter = ((angle.clamp(32.0, 62.0) - 45) / 17).clamp(
      -1.0,
      1.0,
    );
    final steadiness = stability.clamp(0.0, 1.0).toDouble();
    final projector = BasketballProjector(arena);
    final hoopWidth =
        BasketballCourt.rimHalfWidth *
        projector.courtHalfWidthAtDepth(BasketballCourt.hoopZ) *
        2;
    final ballRadius =
        (hoopWidth * 0.4) / projector.ballScaleForDepth(BasketballCourt.hoopZ);
    final travelTime = _lerp(1.08, 0.76, mappedPower);
    final aimX =
        offset.clamp(-1.0, 1.0).toDouble() * _lerp(0.28, 0.36, steadiness);
    final targetY =
        BasketballCourt.rimHeight +
        (rawPower - 0.65) * 0.18 +
        angleFromCenter * 0.055;
    final releaseHeight =
        BasketballCourt.releaseHeight + _lerp(-0.01, 0.015, normalizedAngle);
    final yVelocity =
        (targetY - releaseHeight + 0.5 * gravityY * travelTime * travelTime) /
        travelTime;

    return BasketballBall(
      courtPosition: BasketballCourtPoint(
        x: 0,
        y: releaseHeight,
        z: BasketballCourt.releaseZ,
      ),
      courtVelocity: BasketballCourtVelocity(
        x: aimX / travelTime,
        y: yVelocity,
        z: (BasketballCourt.hoopZ - BasketballCourt.releaseZ) / travelTime,
      ),
      radius: ballRadius,
    );
  }

  BasketballStepResult step(
    BasketballBall ball,
    BasketballHoop hoop,
    Size arena,
    double dt,
  ) {
    if (ball.resolved) {
      return const BasketballStepResult(
        outcome: BasketballShotOutcome.inFlight,
      );
    }

    final safeDt = dt.clamp(0.0, 0.05).toDouble();
    _advanceBall(ball, safeDt);

    if (_crossedHoopPlane(ball) && _isInsideScoreWindow(ball, hoop)) {
      ball.resolved = true;
      return const BasketballStepResult(outcome: BasketballShotOutcome.scored);
    }

    var collision = BasketballCollisionType.none;
    if (_resolveRimCollision(ball, hoop)) {
      collision = BasketballCollisionType.rim;
      ball.lastCollision = BasketballCollisionType.rim;
    }

    if (_resolveBackboardCollision(ball, hoop)) {
      collision = BasketballCollisionType.backboard;
      ball.lastCollision = BasketballCollisionType.backboard;
    }

    if (_isMiss(ball, hoop)) {
      ball.resolved = true;
      return BasketballStepResult(
        outcome: BasketballShotOutcome.missed,
        collision: collision,
        missType: _missType(ball, hoop),
      );
    }

    return BasketballStepResult(
      outcome: BasketballShotOutcome.inFlight,
      collision: collision,
    );
  }

  void advanceResolvedBall(BasketballBall ball, double dt) {
    _advanceBall(ball, dt.clamp(0.0, 0.05).toDouble());
  }

  void _advanceBall(BasketballBall ball, double dt) {
    ball.previousCourtPosition = ball.courtPosition;
    ball.courtVelocity = ball.courtVelocity.translate(dy: -gravityY * dt);
    ball.courtPosition = BasketballCourtPoint(
      x: ball.courtPosition.x + ball.courtVelocity.x * dt,
      y: ball.courtPosition.y + ball.courtVelocity.y * dt,
      z: ball.courtPosition.z + ball.courtVelocity.z * dt,
    );
    ball.ageSeconds += dt;
    ball.recordTrail();
  }

  bool _crossedHoopPlane(BasketballBall ball) {
    return ball.previousCourtPosition.z < BasketballCourt.hoopZ &&
        ball.courtPosition.z >= BasketballCourt.hoopZ &&
        ball.courtVelocity.z > 0 &&
        ball.courtVelocity.y < 0;
  }

  bool _isInsideScoreWindow(BasketballBall ball, BasketballHoop hoop) {
    final crossing = _pointAtZ(ball, BasketballCourt.hoopZ);
    final halfWidth = BasketballCourt.rimHalfWidth * hoop.hitTolerance;
    final heightTolerance =
        BasketballCourt.rimHeightTolerance * _lerp(0.9, 1.0, hoop.hitTolerance);
    final relativeX = crossing.x - hoop.courtX;
    return relativeX.abs() <= halfWidth &&
        (crossing.y - BasketballCourt.rimHeight).abs() <= heightTolerance;
  }

  bool _resolveRimCollision(BasketballBall ball, BasketballHoop hoop) {
    if (ball.isRising) {
      return false;
    }
    if ((ball.courtPosition.z - BasketballCourt.hoopZ).abs() >
        BasketballCourt.rimDepth + BasketballCourt.ballCourtRadius) {
      return false;
    }
    if ((ball.courtPosition.y - BasketballCourt.rimHeight).abs() >
        BasketballCourt.rimCollisionHeight) {
      return false;
    }

    final relativeX = ball.courtPosition.x - hoop.courtX;
    final side = relativeX < 0 ? -1.0 : 1.0;
    final rimX = hoop.courtX + side * BasketballCourt.rimHalfWidth;
    final dx = ball.courtPosition.x - rimX;
    final dy = ball.courtPosition.y - BasketballCourt.rimHeight;
    final distance = math.sqrt(dx * dx + dy * dy);
    final minDistance =
        BasketballCourt.ballCourtRadius + BasketballCourt.rimPostRadius;
    if (distance >= minDistance) {
      return false;
    }

    final nx = distance <= 0.0001 ? side : dx / distance;
    final ny = distance <= 0.0001 ? 0.0 : dy / distance;
    ball.courtPosition = BasketballCourtPoint(
      x: rimX + nx * minDistance,
      y: BasketballCourt.rimHeight + ny * minDistance,
      z: ball.courtPosition.z,
    );

    final velocityAlongNormal =
        ball.courtVelocity.x * nx + ball.courtVelocity.y * ny;
    if (velocityAlongNormal < 0) {
      final impulse = (1 + rimRestitution) * velocityAlongNormal;
      ball.courtVelocity = BasketballCourtVelocity(
        x: (ball.courtVelocity.x - nx * impulse) * rimDamping,
        y: (ball.courtVelocity.y - ny * impulse) * rimDamping,
        z: ball.courtVelocity.z * 0.72,
      );
    }
    ball.collisionCount++;
    return true;
  }

  bool _resolveBackboardCollision(BasketballBall ball, BasketballHoop hoop) {
    if (ball.courtVelocity.z <= 0) {
      return false;
    }

    final relativeX = ball.courtPosition.x - hoop.courtX;
    final inBoardX = relativeX.abs() <= BasketballCourt.backboardHalfWidth;
    final inBoardY =
        ball.courtPosition.y >= BasketballCourt.backboardBottomHeight &&
        ball.courtPosition.y <= BasketballCourt.backboardTopHeight;
    final reachedBoard =
        ball.previousCourtPosition.z <
            BasketballCourt.backboardZ - BasketballCourt.ballCourtRadius &&
        ball.courtPosition.z >=
            BasketballCourt.backboardZ - BasketballCourt.ballCourtRadius;

    if (!inBoardX || !inBoardY || !reachedBoard) {
      return false;
    }

    ball.courtPosition = BasketballCourtPoint(
      x: ball.courtPosition.x,
      y: ball.courtPosition.y,
      z: BasketballCourt.backboardZ - BasketballCourt.ballCourtRadius,
    );
    ball.courtVelocity = BasketballCourtVelocity(
      x: ball.courtVelocity.x * 0.86,
      y: ball.courtVelocity.y * backboardDampingY,
      z: -ball.courtVelocity.z.abs() * backboardRestitutionZ,
    );
    ball.collisionCount++;
    return true;
  }

  bool _isMiss(BasketballBall ball, BasketballHoop hoop) {
    if (ball.collisionCount > 6 || ball.ageSeconds > 4.2) {
      return true;
    }
    if (ball.courtPosition.x.abs() > 1.45 ||
        ball.courtPosition.z < -0.15 ||
        ball.courtPosition.z > 1.58) {
      return true;
    }
    if (ball.courtPosition.y < -0.18 && ball.courtVelocity.y < 0) {
      return true;
    }
    final relativeX = (ball.courtPosition.x - hoop.courtX).abs();
    final clearlyWide =
        relativeX >
        BasketballCourt.rimHalfWidth * 1.3 + BasketballCourt.ballCourtRadius;
    final belowHoop = ball.courtPosition.y < BasketballCourt.rimHeight - 0.22;
    return ball.courtPosition.z > BasketballCourt.hoopZ &&
        ball.courtVelocity.y < 0 &&
        belowHoop &&
        clearlyWide;
  }

  BasketballMissType _missType(BasketballBall ball, BasketballHoop hoop) {
    if (ball.ageSeconds > 4.2) {
      return BasketballMissType.timeout;
    }
    if (ball.lastCollision == BasketballCollisionType.backboard) {
      return BasketballMissType.backboardOut;
    }
    if (ball.lastCollision == BasketballCollisionType.rim) {
      return BasketballMissType.rimOut;
    }
    if (ball.courtPosition.x.abs() > 1.35 || ball.courtPosition.z > 1.52) {
      return BasketballMissType.outOfBounds;
    }

    final relativeX = ball.courtPosition.x - hoop.courtX;
    if (relativeX < -BasketballCourt.rimHalfWidth) {
      return BasketballMissType.left;
    }
    if (relativeX > BasketballCourt.rimHalfWidth) {
      return BasketballMissType.right;
    }
    return ball.courtPosition.z < BasketballCourt.hoopZ
        ? BasketballMissType.short
        : BasketballMissType.long;
  }

  BasketballCourtPoint _pointAtZ(BasketballBall ball, double z) {
    final start = ball.previousCourtPosition;
    final end = ball.courtPosition;
    final dz = end.z - start.z;
    if (dz.abs() <= 0.0001) {
      return end;
    }
    return BasketballCourtPoint.lerp(start, end, (z - start.z) / dz);
  }

  double _lerp(double a, double b, double t) => a + (b - a) * t;
}
