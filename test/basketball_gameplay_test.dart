import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:motionarcade/games/basketball/basketball_game_state.dart';
import 'package:motionarcade/games/basketball/basketball_physics.dart';
import 'package:motionarcade/network/websocket_server_service.dart';
import 'package:motionarcade/shared/models/motion_event.dart';
import 'package:motionarcade/shared/models/player.dart';

void main() {
  group('BasketballGameState', () {
    late WebSocketServerService server;
    late BasketballGameState state;

    setUp(() {
      server = WebSocketServerService();
      state = BasketballGameState(
        server: server,
        initialPlayers: const [
          Player(id: 'p1', name: 'Player 1', deviceLabel: 'phone'),
        ],
        countdownSeconds: 0,
      );
      state.setArenaSize(const Size(800, 450));
    });

    tearDown(() {
      state.dispose();
    });

    test('starts in playing phase when countdown is disabled', () {
      expect(state.phase, BasketballRunPhase.playing);
      expect(state.remainingSeconds, BasketballGameState.runDurationSeconds);
      expect(state.playerStats.single.score, 0);
      expect(state.playerStats.single.streak, 0);
    });

    test('scores a centered shot and updates streak', () {
      state.submitShot(
        ShootEvent(
          playerId: 'p1',
          timestamp: DateTime.fromMillisecondsSinceEpoch(1000),
          power: 0.65,
          angle: 45,
          offset: 0,
          stability: 1,
          holdDurationMs: 600,
        ),
      );

      _pumpUntilResolved(state);

      final stats = state.playerStats.single;
      expect(stats.score, 1);
      expect(stats.streak, 1);
      expect(stats.bestStreak, 1);
      expect(stats.hits, 1);
      expect(state.lastOutcome, BasketballShotOutcome.scored);
    });

    test('miss resets streak but keeps best streak', () {
      state.submitShot(
        ShootEvent(
          playerId: 'p1',
          timestamp: DateTime.fromMillisecondsSinceEpoch(1000),
          power: 0.65,
          angle: 45,
          offset: 0,
          stability: 1,
          holdDurationMs: 600,
        ),
      );
      _pumpUntilResolved(state);
      _pumpUntilBallCleared(state);

      state.submitShot(
        ShootEvent(
          playerId: 'p1',
          timestamp: DateTime.fromMillisecondsSinceEpoch(2000),
          power: 0.35,
          angle: 34,
          offset: 1,
          stability: 0.4,
          holdDurationMs: 500,
        ),
      );
      _pumpUntilResolved(state);

      final stats = state.playerStats.single;
      expect(stats.score, 1);
      expect(stats.streak, 0);
      expect(stats.bestStreak, 1);
      expect(stats.misses, 1);
      expect(state.lastOutcome, BasketballShotOutcome.missed);
    });

    test('keeps resolved ball on screen until it drops out', () {
      state.submitShot(
        ShootEvent(
          playerId: 'p1',
          timestamp: DateTime.fromMillisecondsSinceEpoch(1000),
          power: 0.65,
          angle: 45,
          offset: 0,
          stability: 1,
          holdDurationMs: 600,
        ),
      );

      _pumpUntilResolved(state);

      expect(state.currentBall, isNotNull);
      expect(state.lastOutcome, BasketballShotOutcome.scored);

      state.submitShot(
        ShootEvent(
          playerId: 'p1',
          timestamp: DateTime.fromMillisecondsSinceEpoch(1100),
          power: 0.65,
          angle: 45,
          offset: 0,
          stability: 1,
          holdDurationMs: 600,
        ),
      );

      expect(state.playerStats.single.score, 1);
      expect(state.currentBall, isNotNull);

      _pumpUntilBallCleared(state);

      expect(state.currentBall, isNull);
      expect(state.lastEventLabel, 'Ready shot');
    });

    test('restart clears scores and returns to countdown', () {
      state.submitShot(
        ShootEvent(
          playerId: 'p1',
          timestamp: DateTime.fromMillisecondsSinceEpoch(1000),
          power: 0.65,
          angle: 45,
          offset: 0,
          stability: 1,
          holdDurationMs: 600,
        ),
      );
      _pumpUntilResolved(state);

      state.restartRun();

      expect(state.phase, BasketballRunPhase.countdown);
      expect(state.remainingSeconds, BasketballGameState.runDurationSeconds);
      expect(state.playerStats.single.score, 0);
      expect(state.playerStats.single.bestStreak, 0);
      expect(state.currentBall, isNull);
    });

    test('ends the run after sixty seconds and rejects more shots', () {
      _pumpSeconds(state, BasketballGameState.runDurationSeconds);

      expect(state.phase, BasketballRunPhase.gameOver);
      expect(state.isGameOver, isTrue);
      expect(state.remainingSeconds, 0);
      expect(state.playingSeconds, BasketballGameState.runDurationSeconds);
      expect(state.lastEventLabel, 'Time up');

      state.submitShot(
        ShootEvent(
          playerId: 'p1',
          timestamp: DateTime.fromMillisecondsSinceEpoch(3000),
          power: 0.65,
          angle: 45,
          offset: 0,
          stability: 1,
          holdDurationMs: 100,
        ),
      );

      expect(state.currentBall, isNull);
      expect(state.playerStats.single.score, 0);
    });
  });
}

void _pumpUntilResolved(BasketballGameState state) {
  for (var i = 0; i < 180; i++) {
    state.update(1 / 60, const Size(800, 450));
    if (state.lastOutcome != BasketballShotOutcome.inFlight) {
      return;
    }
  }
}

void _pumpUntilBallCleared(BasketballGameState state) {
  for (var i = 0; i < 240; i++) {
    state.update(1 / 60, const Size(800, 450));
    if (state.currentBall == null) {
      return;
    }
  }
}

void _pumpSeconds(BasketballGameState state, double seconds) {
  final frames = (seconds * 60).ceil();
  for (var i = 0; i < frames; i++) {
    state.update(1 / 60, const Size(800, 450));
  }
}
