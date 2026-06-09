import 'dart:math' as math;
import 'dart:ui';

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
    required this.position,
    required this.velocity,
    Offset? previousPosition,
    this.radius = 14,
    this.ageSeconds = 0,
    this.collisionCount = 0,
    this.resolved = false,
    this.lastCollision = BasketballCollisionType.none,
    List<Offset>? trail,
  }) : previousPosition = previousPosition ?? position,
       trail = trail ?? [position];

  Offset position;
  Offset previousPosition;
  Offset velocity;
  double radius;
  double ageSeconds;
  int collisionCount;
  bool resolved;
  BasketballCollisionType lastCollision;
  final List<Offset> trail;

  void recordTrail() {
    trail.add(position);
    if (trail.length > 24) {
      trail.removeRange(0, trail.length - 24);
    }
  }
}

class BasketballHoop {
  const BasketballHoop({
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
    final scale = _scaleForArena(arena);
    final movement = difficulty.movementOffset(elapsedSeconds) * scale;
    final rimCenter = Offset(arena.width / 2 + movement, arena.height * 0.29);
    final rimWidth = 74.0 * scale;
    final boardWidth = 12.0 * scale;
    final boardHeight = 92.0 * scale;
    final backboardRect = Rect.fromLTWH(
      rimCenter.dx + rimWidth / 2 + 10 * scale,
      rimCenter.dy - boardHeight * 0.72,
      boardWidth,
      boardHeight,
    );

    return BasketballHoop(
      rimCenter: rimCenter,
      rimWidth: rimWidth,
      rimRadius: 7.0 * scale,
      backboardRect: backboardRect,
      hitTolerance: difficulty.hitTolerance,
    );
  }

  final Offset rimCenter;
  final double rimWidth;
  final double rimRadius;
  final Rect backboardRect;
  final double hitTolerance;

  Offset get leftRimCenter => rimCenter.translate(-rimWidth / 2, 0);
  Offset get rightRimCenter => rimCenter.translate(rimWidth / 2, 0);

  static double _scaleForArena(Size arena) {
    if (arena.width <= 0 || arena.height <= 0) {
      return 1;
    }
    return math.min(arena.width / 800, arena.height / 450).clamp(0.65, 1.8);
  }
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
    this.gravityY = 1500,
    this.rimRestitution = 0.62,
    this.rimDamping = 0.92,
    this.backboardRestitutionX = 0.55,
    this.backboardDampingY = 0.82,
  });

  final double gravityY;
  final double rimRestitution;
  final double rimDamping;
  final double backboardRestitutionX;
  final double backboardDampingY;

  BasketballBall launchBall({
    required Size arena,
    required double power,
    required double angle,
    required double offset,
    required double stability,
  }) {
    final scaleX = arena.width <= 0 ? 1.0 : arena.width / 800;
    final scaleY = arena.height <= 0 ? 1.0 : arena.height / 450;
    final start = Offset(arena.width / 2, arena.height - 72 * scaleY);
    final rawPower = power.clamp(0.0, 1.0);
    final mappedPower = 1 - math.pow(1 - rawPower, 1.6).toDouble();
    final normalizedAngle = ((angle.clamp(32.0, 62.0) - 32) / 30).clamp(
      0.0,
      1.0,
    );
    final arc = _lerp(0.86, 1.16, normalizedAngle);
    final steadiness = stability.clamp(0.0, 1.0);
    final lateral = offset.clamp(-1.0, 1.0) * _lerp(0.78, 1.0, steadiness);

    return BasketballBall(
      position: start,
      velocity: Offset(
        lateral * 260 * scaleX,
        -_lerp(720, 1040, mappedPower) * arc * scaleY,
      ),
      radius: 14 * math.min(scaleX, scaleY).clamp(0.75, 1.35),
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

    final safeDt = dt.clamp(0.0, 0.05);
    ball.previousPosition = ball.position;
    ball.velocity = ball.velocity.translate(0, gravityY * safeDt);
    ball.position = ball.position + ball.velocity * safeDt;
    ball.ageSeconds += safeDt;
    ball.recordTrail();

    if (_crossedRimPlane(ball, hoop) && _isInsideScoreWindow(ball, hoop)) {
      ball.resolved = true;
      return const BasketballStepResult(outcome: BasketballShotOutcome.scored);
    }

    var collision = BasketballCollisionType.none;
    if (_resolveRimCollision(ball, hoop.leftRimCenter, hoop.rimRadius) ||
        _resolveRimCollision(ball, hoop.rightRimCenter, hoop.rimRadius)) {
      collision = BasketballCollisionType.rim;
      ball.lastCollision = BasketballCollisionType.rim;
    }

    if (_resolveBackboardCollision(ball, hoop.backboardRect)) {
      collision = BasketballCollisionType.backboard;
      ball.lastCollision = BasketballCollisionType.backboard;
    }

    if (_isMiss(ball, hoop, arena)) {
      ball.resolved = true;
      return BasketballStepResult(
        outcome: BasketballShotOutcome.missed,
        collision: collision,
        missType: _missType(ball, hoop, arena),
      );
    }

    return BasketballStepResult(
      outcome: BasketballShotOutcome.inFlight,
      collision: collision,
    );
  }

  bool _crossedRimPlane(BasketballBall ball, BasketballHoop hoop) {
    return ball.previousPosition.dy < hoop.rimCenter.dy &&
        ball.position.dy >= hoop.rimCenter.dy &&
        ball.velocity.dy > 0;
  }

  bool _isInsideScoreWindow(BasketballBall ball, BasketballHoop hoop) {
    final effectiveHalfWidth = (hoop.rimWidth / 2) * hoop.hitTolerance;
    return (ball.position.dx - hoop.rimCenter.dx).abs() <= effectiveHalfWidth;
  }

  bool _resolveRimCollision(
    BasketballBall ball,
    Offset rimCenter,
    double rimRadius,
  ) {
    final delta = ball.position - rimCenter;
    final distance = delta.distance;
    final minDistance = ball.radius + rimRadius;
    if (distance >= minDistance) {
      return false;
    }

    final normal = distance <= 0.0001
        ? const Offset(0, -1)
        : delta * (1 / distance);
    ball.position = rimCenter + normal * minDistance;

    final velocityAlongNormal = _dot(ball.velocity, normal);
    if (velocityAlongNormal < 0) {
      ball.velocity =
          ball.velocity - normal * ((1 + rimRestitution) * velocityAlongNormal);
      ball.velocity = ball.velocity * rimDamping;
    }
    ball.collisionCount++;
    return true;
  }

  bool _resolveBackboardCollision(BasketballBall ball, Rect backboard) {
    if (!backboard.inflate(ball.radius).contains(ball.position)) {
      return false;
    }
    if (ball.velocity.dx <= 0) {
      return false;
    }

    ball.position = Offset(backboard.left - ball.radius, ball.position.dy);
    ball.velocity = Offset(
      -ball.velocity.dx * backboardRestitutionX,
      ball.velocity.dy * backboardDampingY,
    );
    ball.collisionCount++;
    return true;
  }

  bool _isMiss(BasketballBall ball, BasketballHoop hoop, Size arena) {
    if (ball.collisionCount > 5 || ball.ageSeconds > 3.5) {
      return true;
    }
    if (ball.position.dy > arena.height + ball.radius * 2) {
      return true;
    }
    if (ball.position.dx < -ball.radius * 3 ||
        ball.position.dx > arena.width + ball.radius * 3) {
      return true;
    }

    final isFallingBelowHoop =
        ball.position.dy > hoop.rimCenter.dy + arena.height * 0.28 &&
        ball.velocity.dy > 0;
    final isClearlyWide =
        (ball.position.dx - hoop.rimCenter.dx).abs() >
        hoop.rimWidth * 1.25 + ball.radius;
    return isFallingBelowHoop && isClearlyWide;
  }

  BasketballMissType _missType(
    BasketballBall ball,
    BasketballHoop hoop,
    Size arena,
  ) {
    if (ball.ageSeconds > 3.5) {
      return BasketballMissType.timeout;
    }
    if (ball.lastCollision == BasketballCollisionType.backboard) {
      return BasketballMissType.backboardOut;
    }
    if (ball.lastCollision == BasketballCollisionType.rim) {
      return BasketballMissType.rimOut;
    }
    if (ball.position.dx < -ball.radius * 2 ||
        ball.position.dx > arena.width + ball.radius * 2) {
      return BasketballMissType.outOfBounds;
    }
    if (ball.position.dx < hoop.rimCenter.dx - hoop.rimWidth / 2) {
      return BasketballMissType.left;
    }
    if (ball.position.dx > hoop.rimCenter.dx + hoop.rimWidth / 2) {
      return BasketballMissType.right;
    }
    return ball.ageSeconds < 1.0
        ? BasketballMissType.short
        : BasketballMissType.long;
  }

  double _dot(Offset a, Offset b) => a.dx * b.dx + a.dy * b.dy;

  double _lerp(double a, double b, double t) => a + (b - a) * t;
}
