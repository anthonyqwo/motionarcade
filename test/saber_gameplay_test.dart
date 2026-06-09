import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:motionarcade/games/saber/saber_game_state.dart';
import 'package:motionarcade/games/saber/saber_target.dart';
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

    test(
      'SaberGameState spawns targets and handles misses when depth exceeds 1.0',
      () {
        final state = SaberGameState(
          server: mockServer,
          initialPlayers: players,
        );
        addTearDown(state.dispose);

        expect(state.targets, isEmpty);

        state.update(2.6);
        expect(state.targets, isNotEmpty);
        expect(state.targets.first.status, equals(SaberTargetStatus.active));
        expect(state.targets.first.depth, closeTo(2.6 * state.speed, 0.001));

        state.targets.first.depth = 1.05;
        state.update(0.1);
        expect(state.targets.first.status, equals(SaberTargetStatus.missed));
        expect(state.scoring.score, equals(0));
        expect(state.scoring.combo, equals(0));
      },
    );

    test('slash effects only trigger for matching active targets', () async {
      final motionEvents = StreamController<MotionEvent>.broadcast();
      final state = SaberGameState(
        server: mockServer,
        initialPlayers: players,
        motionEvents: motionEvents.stream,
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
    });
  });
}
