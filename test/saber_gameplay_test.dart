import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:motionarcade/games/saber/saber_game_state.dart';
import 'package:motionarcade/games/saber/saber_target.dart';
import 'package:motionarcade/games/saber/saber_visual_style.dart';
import 'package:motionarcade/network/websocket_server_service.dart';
import 'package:motionarcade/shared/models/motion_event.dart';
import 'package:motionarcade/shared/models/player.dart';

void main() {
  group('Saber Gameplay Tests', () {
    late WebSocketServerService mockServer;
    late List<Player> players;

    setUp(() {
      mockServer = WebSocketServerService();
      players = [
        const Player(id: 'p1', name: 'Player 1', deviceLabel: 'phone'),
      ];
    });

    test('target updates depth and isCut animation progress correctly', () {
      final target = SaberTarget(
        id: 't1',
        direction: MotionDirection.up,
        lane: 0.0,
        spawnTime: DateTime.now(),
        depth: 0.0,
      );

      target.update(1.0, 0.4);
      expect(target.depth, equals(0.4));

      target.status = SaberTargetStatus.cutPerfect;
      target.update(0.1, 0.4);
      expect(target.cutProgress, closeTo(0.35, 0.01));
    });

    test('missed targets fade out and become removable quickly', () {
      final target = SaberTarget(
        id: 't1',
        direction: MotionDirection.up,
        lane: 0.0,
        spawnTime: DateTime.now(),
        depth: 1.05,
      );

      target.markMissed();
      expect(target.depth, equals(1.0));
      expect(target.missProgress, equals(0.0));

      target.update(0.36, 0.4);
      expect(target.missProgress, closeTo(0.5, 0.01));
      expect(target.isFinished, isFalse);

      target.update(0.36, 0.4);
      expect(target.missProgress, equals(1.0));
      expect(target.isFinished, isTrue);
    });

    test(
      'SaberGameState spawns targets and handles misses when depth exceeds 1.0',
      () {
        final state = SaberGameState(
          server: mockServer,
          initialPlayers: players,
          countdownSeconds: 0,
        );
        addTearDown(state.dispose);

        expect(state.targets, isEmpty);

        state.update(2.6);
        expect(state.targets, isNotEmpty);
        expect(state.targets.first.status, equals(SaberTargetStatus.active));
        expect(state.targets.first.depth, equals(0.0));

        state.targets.first.depth = 1.05;
        state.update(0.1);
        expect(state.targets.first.status, equals(SaberTargetStatus.missed));
        expect(state.scoring.score, equals(0));
        expect(state.scoring.combo, equals(0));
      },
    );

    test('SaberGameState spawns targets across more than three fixed points', () {
      final state = SaberGameState(
        server: mockServer,
        initialPlayers: players,
        random: math.Random(4),
        countdownSeconds: 0,
      );
      addTearDown(state.dispose);
      state.speed = 0;

      final positions = <String>{};
      String? previousPosition;

      for (var i = 0; i < 8; i++) {
        state.update(1.7);
        final target = state.targets.last;
        final position =
            '${target.lane.toStringAsFixed(2)},${target.row.toStringAsFixed(2)}';
        positions.add(position);
        if (previousPosition != null) {
          expect(position, isNot(previousPosition));
        }
        previousPosition = position;
      }

      expect(positions.length, greaterThan(3));
      expect(positions.any((position) => !position.endsWith(',0.00')), isTrue);
    });

    test('slash effects only trigger for matching active targets', () async {
      final motionEvents = StreamController<MotionEvent>.broadcast();
      final state = SaberGameState(
        server: mockServer,
        initialPlayers: players,
        motionEvents: motionEvents.stream,
        countdownSeconds: 0,
      );
      addTearDown(state.dispose);
      addTearDown(motionEvents.close);

      final slashWithoutTarget = SlashEvent(
        playerId: 'p1',
        timestamp: DateTime.fromMillisecondsSinceEpoch(1000),
        direction: MotionDirection.up,
        power: 0.7,
        durationMs: 100,
      );
      motionEvents.add(slashWithoutTarget);
      await Future<void>.delayed(Duration.zero);

      expect(state.lastSlash, isNull);

      state.targets.add(
        SaberTarget(
          id: 't1',
          direction: MotionDirection.right,
          lane: 0,
          spawnTime: DateTime.fromMillisecondsSinceEpoch(1000),
          depth: 0.9,
        ),
      );

      final wrongSlash = SlashEvent(
        playerId: 'p1',
        timestamp: DateTime.fromMillisecondsSinceEpoch(1100),
        direction: MotionDirection.left,
        power: 0.7,
        durationMs: 100,
      );
      motionEvents.add(wrongSlash);
      await Future<void>.delayed(Duration.zero);

      expect(state.lastSlash, isNull);

      state.targets.add(
        SaberTarget(
          id: 't2',
          direction: MotionDirection.up,
          lane: 0,
          spawnTime: DateTime.fromMillisecondsSinceEpoch(1000),
          depth: 0.9,
        ),
      );

      final matchingSlash = SlashEvent(
        playerId: 'p1',
        timestamp: DateTime.fromMillisecondsSinceEpoch(1200),
        direction: MotionDirection.up,
        power: 0.7,
        durationMs: 100,
      );
      motionEvents.add(matchingSlash);
      await Future<void>.delayed(Duration.zero);

      expect(state.lastSlash, matchingSlash);
      expect(state.lastHitEffect, isNotNull);
      expect(state.lastHitEffect!.targetDirection, MotionDirection.up);
      expect(state.lastHitEffect!.result, FeedbackResult.good);
      expect(state.lastHitEffect!.addedScore, 60);
    });

    test(
      'saber visual style keeps effect colors aligned with target colors',
      () {
        expect(
          saberColorForDirection(MotionDirection.left),
          const Color(0xFFF97316),
        );
        expect(
          saberColorForDirection(MotionDirection.right),
          const Color(0xFFA3E635),
        );
        expect(
          saberScoreLabel(result: FeedbackResult.perfect, addedScore: 500),
          'PERFECT +500',
        );
        expect(
          saberScoreColorForResult(FeedbackResult.perfect),
          isNot(saberScoreColorForResult(FeedbackResult.good)),
        );
      },
    );

    test('countdown delays spawning and starts the run cleanly', () {
      final state = SaberGameState(
        server: mockServer,
        initialPlayers: players,
        random: math.Random(1),
      );
      addTearDown(state.dispose);

      expect(state.phase, equals(SaberRunPhase.countdown));
      expect(state.targets, isEmpty);

      state.update(1.0);
      expect(state.phase, equals(SaberRunPhase.countdown));
      expect(state.targets, isEmpty);
      expect(state.survivedSeconds, equals(0.0));

      state.update(2.1);
      expect(state.phase, equals(SaberRunPhase.playing));
      expect(state.countdownRemaining, equals(0.0));
      expect(state.survivedSeconds, closeTo(0.1, 0.001));
      expect(state.targets, isNotEmpty);
    });

    test('three shared misses end the run and stop new spawns', () {
      final state = SaberGameState(
        server: mockServer,
        initialPlayers: players,
        countdownSeconds: 0,
      );
      addTearDown(state.dispose);

      for (var i = 0; i < 3; i++) {
        state.targets.add(
          SaberTarget(
            id: 'miss_$i',
            direction: MotionDirection.up,
            lane: 0,
            spawnTime: DateTime.fromMillisecondsSinceEpoch(1000 + i),
            depth: 1.05,
          ),
        );
        state.update(0.1);
      }

      expect(state.sharedLives, equals(0));
      expect(state.teamMisses, equals(3));
      expect(state.isGameOver, isTrue);
      expect(state.gameOverReason, equals(SaberGameOverReason.outOfLives));

      final targetCount = state.targets.length;
      state.update(5.0);
      expect(state.targets.length, lessThanOrEqualTo(targetCount));
    });

    test(
      'wrong direction consumes a shared life and marks that player miss',
      () async {
        final motionEvents = StreamController<MotionEvent>.broadcast();
        final state = SaberGameState(
          server: mockServer,
          initialPlayers: players,
          motionEvents: motionEvents.stream,
          countdownSeconds: 0,
        );
        addTearDown(state.dispose);
        addTearDown(motionEvents.close);

        state.targets.add(
          SaberTarget(
            id: 'wrong_direction_target',
            direction: MotionDirection.right,
            lane: 0,
            spawnTime: DateTime.fromMillisecondsSinceEpoch(1000),
            depth: 0.9,
          ),
        );

        motionEvents.add(
          SlashEvent(
            playerId: 'p1',
            timestamp: DateTime.fromMillisecondsSinceEpoch(1100),
            direction: MotionDirection.left,
            power: 0.7,
            durationMs: 100,
          ),
        );
        await Future<void>.delayed(Duration.zero);

        expect(state.sharedLives, equals(2));
        expect(state.playerStats.single.misses, equals(1));
        expect(state.scoring.combo, equals(0));
        expect(state.targets.single.status, equals(SaberTargetStatus.missed));
      },
    );

    test('multiplayer keeps shared lives and individual scores', () async {
      final motionEvents = StreamController<MotionEvent>.broadcast();
      final state = SaberGameState(
        server: mockServer,
        initialPlayers: [
          const Player(id: 'p1', name: 'Player 1', deviceLabel: 'phone'),
          const Player(id: 'p2', name: 'Player 2', deviceLabel: 'phone'),
        ],
        motionEvents: motionEvents.stream,
        countdownSeconds: 0,
      );
      addTearDown(state.dispose);
      addTearDown(motionEvents.close);

      state.targets.add(
        SaberTarget(
          id: 'p2_target',
          direction: MotionDirection.up,
          lane: 0,
          spawnTime: DateTime.fromMillisecondsSinceEpoch(1000),
          depth: 0.93,
        ),
      );

      motionEvents.add(
        SlashEvent(
          playerId: 'p2',
          timestamp: DateTime.fromMillisecondsSinceEpoch(1100),
          direction: MotionDirection.up,
          power: 0.8,
          durationMs: 100,
        ),
      );
      await Future<void>.delayed(Duration.zero);

      expect(state.sharedLives, equals(3));
      expect(state.scoringForPlayer('p1').score, equals(0));
      expect(state.scoringForPlayer('p2').score, greaterThan(0));
      expect(state.playerStats.first.player.id, equals('p2'));
      expect(state.playerStats.first.hits, equals(1));
      expect(state.lastHitEffect?.result, FeedbackResult.perfect);
      expect(state.lastHitEffect?.targetDirection, MotionDirection.up);
    });
  });
}
