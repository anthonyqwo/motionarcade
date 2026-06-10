import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:motionarcade/games/basketball/basketball_court_space.dart';
import 'package:motionarcade/games/basketball/basketball_physics.dart';

void main() {
  group('BasketballPhysics', () {
    const physics = BasketballPhysics();
    const arena = Size(800, 450);

    BasketballHoop hoopFor({int streak = 0}) {
      return BasketballHoop.forArena(
        arena: arena,
        difficulty: BasketballDifficulty.forStreak(streak),
        elapsedSeconds: 0,
      );
    }

    test('scores when the ball falls through the hoop plane', () {
      final hoop = hoopFor();
      final ball = BasketballBall(
        courtPosition: const BasketballCourtPoint(
          x: 0,
          y: BasketballCourt.rimHeight + 0.02,
          z: BasketballCourt.hoopZ - 0.02,
        ),
        courtVelocity: const BasketballCourtVelocity(x: 0, y: -0.2, z: 1.0),
      );

      final result = physics.step(ball, hoop, arena, 0.04);

      expect(result.scored, isTrue);
      expect(ball.resolved, isTrue);
    });

    test('bounces from side rim collision', () {
      final hoop = hoopFor();
      final ball = BasketballBall(
        courtPosition: BasketballCourtPoint(
          x:
              hoop.courtX -
              BasketballCourt.rimHalfWidth -
              BasketballCourt.ballCourtRadius * 0.55,
          y: BasketballCourt.rimHeight,
          z: BasketballCourt.hoopZ,
        ),
        courtVelocity: const BasketballCourtVelocity(x: 0.55, y: -0.15, z: 0),
      );

      final result = physics.step(ball, hoop, arena, 0);

      expect(result.collision, BasketballCollisionType.rim);
      expect(ball.courtVelocity.x, lessThan(0));
      expect(ball.collisionCount, 1);
    });

    test('does not bounce from rim while rising under the basket', () {
      final hoop = hoopFor();
      final ball = BasketballBall(
        courtPosition: BasketballCourtPoint(
          x: hoop.courtX - BasketballCourt.rimHalfWidth,
          y: BasketballCourt.rimHeight - 0.04,
          z: BasketballCourt.hoopZ,
        ),
        courtVelocity: const BasketballCourtVelocity(x: 0, y: 0.45, z: 0.2),
      );

      final result = physics.step(ball, hoop, arena, 0);

      expect(result.collision, BasketballCollisionType.none);
      expect(ball.courtVelocity.y, greaterThan(0));
      expect(ball.collisionCount, 0);
    });

    test('bounces from backboard collision', () {
      final hoop = hoopFor();
      final ball = BasketballBall(
        courtPosition: BasketballCourtPoint(
          x: hoop.courtX,
          y: BasketballCourt.rimHeight + 0.14,
          z:
              BasketballCourt.backboardZ -
              BasketballCourt.ballCourtRadius -
              0.01,
        ),
        courtVelocity: const BasketballCourtVelocity(x: 0.04, y: -0.1, z: 1.0),
      );

      final result = physics.step(ball, hoop, arena, 0.02);

      expect(result.collision, BasketballCollisionType.backboard);
      expect(ball.courtVelocity.z, lessThan(0));
      expect(ball.collisionCount, 1);
    });

    test('does not collide with an invisible wall beside the right rim', () {
      final hoop = hoopFor();
      final ball = BasketballBall(
        courtPosition: BasketballCourtPoint(
          x: hoop.courtX + BasketballCourt.rimHalfWidth + 0.24,
          y: BasketballCourt.rimHeight + 0.12,
          z: BasketballCourt.hoopZ,
        ),
        courtVelocity: const BasketballCourtVelocity(x: 0.35, y: -0.1, z: 0.4),
      );

      final result = physics.step(ball, hoop, arena, 0);

      expect(result.collision, BasketballCollisionType.none);
      expect(ball.courtVelocity.x, greaterThan(0));
      expect(ball.collisionCount, 0);
    });

    test('a centered normal shot reaches the basket', () {
      final hoop = hoopFor();
      final ball = physics.launchBall(
        arena: arena,
        power: 0.65,
        angle: 45,
        offset: 0,
        stability: 1,
      );

      BasketballStepResult result = const BasketballStepResult(
        outcome: BasketballShotOutcome.inFlight,
      );
      for (
        var i = 0;
        i < 180 && result.outcome == BasketballShotOutcome.inFlight;
        i++
      ) {
        result = physics.step(ball, hoop, arena, 1 / 60);
      }

      expect(result.scored, isTrue);
    });

    test('wide offset changes the hoop-plane target enough to miss', () {
      final hoop = hoopFor();
      final ball = physics.launchBall(
        arena: arena,
        power: 0.65,
        angle: 45,
        offset: 1,
        stability: 1,
      );

      BasketballStepResult result = const BasketballStepResult(
        outcome: BasketballShotOutcome.inFlight,
      );
      for (
        var i = 0;
        i < 220 && result.outcome == BasketballShotOutcome.inFlight;
        i++
      ) {
        result = physics.step(ball, hoop, arena, 1 / 60);
      }

      expect(result.missed, isTrue);
      expect(ball.courtPosition.x, greaterThan(hoop.courtX));
      expect(result.missType, isNot(BasketballMissType.left));
    });

    test('difficulty starts moving the hoop after ten streak', () {
      final warmup = BasketballDifficulty.forStreak(4);
      final moving = BasketballDifficulty.forStreak(10);

      expect(warmup.hoopSpeed, 0);
      expect(moving.hoopSpeed, greaterThan(0));
      expect(moving.hoopAmplitude, greaterThan(0));
    });
  });
}
