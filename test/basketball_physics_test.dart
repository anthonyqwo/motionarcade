import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
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

    test('scores when the ball falls through the rim plane', () {
      final hoop = hoopFor();
      final ball = BasketballBall(
        position: Offset(hoop.rimCenter.dx, hoop.rimCenter.dy - 2),
        velocity: const Offset(0, 40),
      );

      final result = physics.step(ball, hoop, arena, 0.04);

      expect(result.scored, isTrue);
      expect(ball.resolved, isTrue);
    });

    test('bounces from rim circle collision', () {
      final hoop = hoopFor();
      final ball = BasketballBall(
        position: hoop.leftRimCenter.translate(-20, 0),
        velocity: const Offset(120, 0),
      );

      final result = physics.step(ball, hoop, arena, 0);

      expect(result.collision, BasketballCollisionType.rim);
      expect(ball.velocity.dx, lessThan(0));
      expect(ball.collisionCount, 1);
    });

    test('bounces from backboard collision', () {
      final hoop = hoopFor();
      final ball = BasketballBall(
        position: Offset(
          hoop.backboardRect.left - 4,
          hoop.backboardRect.center.dy,
        ),
        velocity: const Offset(140, -20),
      );

      final result = physics.step(ball, hoop, arena, 0);

      expect(result.collision, BasketballCollisionType.backboard);
      expect(ball.velocity.dx, lessThan(0));
      expect(ball.collisionCount, 1);
    });

    test('does not collide with an invisible wall beside the right rim', () {
      final hoop = hoopFor();
      final ball = BasketballBall(
        position: hoop.rightRimCenter.translate(12, -30),
        velocity: const Offset(140, -20),
      );

      final result = physics.step(ball, hoop, arena, 0);

      expect(result.collision, BasketballCollisionType.none);
      expect(ball.velocity.dx, greaterThan(0));
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
        i < 160 && result.outcome == BasketballShotOutcome.inFlight;
        i++
      ) {
        result = physics.step(ball, hoop, arena, 1 / 60);
      }

      expect(result.scored, isTrue);
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
