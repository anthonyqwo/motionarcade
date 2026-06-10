import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/foundation.dart';

import '../../network/websocket_server_service.dart';
import '../../shared/models/motion_event.dart';
import '../../shared/models/player.dart';
import 'basketball_physics.dart';
import 'basketball_projection.dart';

enum BasketballRunPhase { countdown, playing }

class BasketballPlayerStats {
  const BasketballPlayerStats({
    required this.player,
    required this.score,
    required this.streak,
    required this.bestStreak,
    required this.hits,
    required this.misses,
  });

  final Player player;
  final int score;
  final int streak;
  final int bestStreak;
  final int hits;
  final int misses;
}

class BasketballGameState extends ChangeNotifier {
  BasketballGameState({
    required this.server,
    required List<Player> initialPlayers,
    Stream<MotionEvent>? motionEvents,
    BasketballPhysics physics = const BasketballPhysics(),
    double countdownSeconds = _defaultCountdownSeconds,
  }) : players = List.from(initialPlayers),
       _physics = physics,
       _phase = countdownSeconds > 0
           ? BasketballRunPhase.countdown
           : BasketballRunPhase.playing,
       _countdownRemaining = countdownSeconds {
    _eventSub = server.events.listen(_handleEvent);
    _motionEventSub = motionEvents?.listen(_handleEvent);
    for (final player in players) {
      _ensureScoreBuckets(player.id);
    }
  }

  static const double _defaultCountdownSeconds = 3.0;

  final WebSocketServerService server;
  final List<Player> players;
  final BasketballPhysics _physics;
  final Map<String, int> _scoreByPlayer = {};
  final Map<String, int> _streakByPlayer = {};
  final Map<String, int> _bestStreakByPlayer = {};
  final Map<String, int> _hitsByPlayer = {};
  final Map<String, int> _missesByPlayer = {};

  StreamSubscription<MotionEvent>? _eventSub;
  StreamSubscription<MotionEvent>? _motionEventSub;
  BasketballRunPhase _phase;
  double _countdownRemaining;
  double _elapsedSeconds = 0;
  double _playingSeconds = 0;
  Size _arenaSize = const Size(800, 450);
  String? _activePlayerId;

  BasketballBall? currentBall;
  ShootEvent? lastShot;
  String lastEventLabel = 'Ready';
  BasketballShotOutcome lastOutcome = BasketballShotOutcome.inFlight;
  BasketballMissType? lastMissType;

  BasketballRunPhase get phase => _phase;
  double get countdownRemaining => _countdownRemaining.clamp(0.0, 99.0);
  double get playingSeconds => _playingSeconds;
  bool get isPlaying => phase == BasketballRunPhase.playing;
  String? get activePlayerId => _activePlayerId;

  int get leadingStreak {
    if (_streakByPlayer.isEmpty) {
      return 0;
    }
    return _streakByPlayer.values.reduce(math.max);
  }

  BasketballDifficulty get difficulty {
    final activePlayerId = _activePlayerId;
    final activeStreak = activePlayerId == null
        ? null
        : _streakByPlayer[activePlayerId];
    return BasketballDifficulty.forStreak(activeStreak ?? leadingStreak);
  }

  BasketballHoop get currentHoop {
    return BasketballHoop.forArena(
      arena: _arenaSize,
      difficulty: difficulty,
      elapsedSeconds: _elapsedSeconds,
    );
  }

  List<BasketballPlayerStats> get playerStats {
    return [
      for (final player in players)
        BasketballPlayerStats(
          player: player,
          score: _scoreByPlayer[player.id] ?? 0,
          streak: _streakByPlayer[player.id] ?? 0,
          bestStreak: _bestStreakByPlayer[player.id] ?? 0,
          hits: _hitsByPlayer[player.id] ?? 0,
          misses: _missesByPlayer[player.id] ?? 0,
        ),
    ]..sort((a, b) {
      final scoreCompare = b.score.compareTo(a.score);
      if (scoreCompare != 0) {
        return scoreCompare;
      }
      return b.bestStreak.compareTo(a.bestStreak);
    });
  }

  void setArenaSize(Size size) {
    if (size.width <= 0 || size.height <= 0) {
      return;
    }
    _arenaSize = size;
  }

  void restartRun({double countdownSeconds = _defaultCountdownSeconds}) {
    currentBall = null;
    lastShot = null;
    lastOutcome = BasketballShotOutcome.inFlight;
    lastMissType = null;
    lastEventLabel = 'Restart';
    _activePlayerId = null;
    _elapsedSeconds = 0;
    _playingSeconds = 0;
    _countdownRemaining = countdownSeconds;
    _phase = countdownSeconds > 0
        ? BasketballRunPhase.countdown
        : BasketballRunPhase.playing;
    for (final player in players) {
      _scoreByPlayer[player.id] = 0;
      _streakByPlayer[player.id] = 0;
      _bestStreakByPlayer[player.id] = 0;
      _hitsByPlayer[player.id] = 0;
      _missesByPlayer[player.id] = 0;
    }
    notifyListeners();
  }

  void update(double dt, Size arenaSize) {
    setArenaSize(arenaSize);
    final safeDt = dt.clamp(0.0, 0.05).toDouble();
    _elapsedSeconds += safeDt;
    var needsNotify = false;

    if (phase == BasketballRunPhase.countdown) {
      _countdownRemaining -= safeDt;
      if (_countdownRemaining <= 0) {
        _countdownRemaining = 0;
        _phase = BasketballRunPhase.playing;
        lastEventLabel = 'Ready shot';
      }
      needsNotify = true;
    } else {
      _playingSeconds += safeDt;
    }

    final ball = currentBall;
    if (ball != null && isPlaying) {
      if (ball.resolved) {
        _advanceResolvedBall(ball, safeDt);
        if (_isBallBelowScreen(ball)) {
          currentBall = null;
          lastEventLabel = 'Ready shot';
        }
        needsNotify = true;
      } else {
        final result = _physics.step(ball, currentHoop, _arenaSize, safeDt);
        if (result.scored) {
          _registerScore();
          needsNotify = true;
        } else if (result.missed) {
          _registerMiss(result.missType ?? BasketballMissType.long);
          needsNotify = true;
        }
      }
    }

    if (needsNotify) {
      notifyListeners();
    }
  }

  void submitShot(ShootEvent event) {
    if (!isPlaying) {
      return;
    }
    _ensurePlayer(event.playerId);

    final existingBall = currentBall;
    if (existingBall != null) {
      server.sendToPlayer(
        event.playerId,
        FeedbackEvent(
          playerId: event.playerId,
          timestamp: DateTime.now(),
          result: FeedbackResult.weak,
          haptic: HapticPattern.light,
          durationMs: 60,
          message: 'Wait for the ball to drop',
        ),
      );
      return;
    }

    _activePlayerId = event.playerId;
    lastShot = event;
    lastOutcome = BasketballShotOutcome.inFlight;
    lastMissType = null;
    lastEventLabel = 'Shot released';
    currentBall = _physics.launchBall(
      arena: _arenaSize,
      power: event.power,
      angle: event.angle,
      offset: event.offset,
      stability: event.stability,
    );
    notifyListeners();
  }

  @override
  void dispose() {
    unawaited(_eventSub?.cancel());
    unawaited(_motionEventSub?.cancel());
    super.dispose();
  }

  void _handleEvent(MotionEvent event) {
    if (event is JoinEvent) {
      _handleJoin(event);
    } else if (event is DisconnectEvent) {
      _handleDisconnect(event);
    } else if (event is ShootEvent) {
      submitShot(event);
    } else if (event is ShootHoldEvent) {
      lastEventLabel = event.pressed ? 'Aiming' : 'Released';
      notifyListeners();
    }
  }

  void _handleJoin(JoinEvent event) {
    final index = players.indexWhere((p) => p.id == event.playerId);
    final player = Player(
      id: event.playerId,
      name: event.name,
      deviceLabel: event.device,
      status: PlayerConnectionStatus.connected,
    );
    if (index == -1) {
      players.add(player);
    } else {
      players[index] = player;
    }
    _ensureScoreBuckets(event.playerId);
    lastEventLabel = 'Join: ${event.name}';
    notifyListeners();
  }

  void _handleDisconnect(DisconnectEvent event) {
    final index = players.indexWhere((p) => p.id == event.playerId);
    if (index != -1) {
      final player = players[index];
      players[index] = Player(
        id: player.id,
        name: player.name,
        deviceLabel: player.deviceLabel,
        status: PlayerConnectionStatus.disconnected,
      );
      lastEventLabel = 'Disconnect: ${player.name}';
      notifyListeners();
    }
  }

  void _registerScore() {
    final playerId = _activePlayerId;
    if (playerId == null) {
      return;
    }
    _ensureScoreBuckets(playerId);
    final streak = (_streakByPlayer[playerId] ?? 0) + 1;
    _scoreByPlayer[playerId] = (_scoreByPlayer[playerId] ?? 0) + 1;
    _streakByPlayer[playerId] = streak;
    _bestStreakByPlayer[playerId] = math.max(
      _bestStreakByPlayer[playerId] ?? 0,
      streak,
    );
    _hitsByPlayer[playerId] = (_hitsByPlayer[playerId] ?? 0) + 1;
    lastOutcome = BasketballShotOutcome.scored;
    lastMissType = null;
    lastEventLabel = streak >= 10 ? 'Nice streak: $streak' : 'Bucket';

    final feedback = (lastShot?.stability ?? 0) >= 0.82
        ? FeedbackResult.perfect
        : FeedbackResult.good;
    server.sendToPlayer(
      playerId,
      FeedbackEvent(
        playerId: playerId,
        timestamp: DateTime.now(),
        result: feedback,
        haptic: feedback == FeedbackResult.perfect
            ? HapticPattern.perfect
            : HapticPattern.good,
        durationMs: feedback == FeedbackResult.perfect ? 120 : 90,
        message: feedback == FeedbackResult.perfect ? 'Perfect shot' : 'Made',
      ),
    );
  }

  void _registerMiss(BasketballMissType missType) {
    final playerId = _activePlayerId;
    if (playerId == null) {
      return;
    }
    _ensureScoreBuckets(playerId);
    _streakByPlayer[playerId] = 0;
    _missesByPlayer[playerId] = (_missesByPlayer[playerId] ?? 0) + 1;
    lastOutcome = BasketballShotOutcome.missed;
    lastMissType = missType;
    lastEventLabel = _missLabel(missType);

    server.sendToPlayer(
      playerId,
      FeedbackEvent(
        playerId: playerId,
        timestamp: DateTime.now(),
        result: FeedbackResult.miss,
        haptic: HapticPattern.miss,
        durationMs: 140,
        message: lastEventLabel,
      ),
    );
  }

  void _ensurePlayer(String playerId) {
    final index = players.indexWhere((p) => p.id == playerId);
    if (index == -1) {
      players.add(
        Player(
          id: playerId,
          name: 'Player ${players.length + 1}',
          deviceLabel: 'controller',
          status: PlayerConnectionStatus.connected,
        ),
      );
    }
    _ensureScoreBuckets(playerId);
  }

  void _ensureScoreBuckets(String playerId) {
    _scoreByPlayer.putIfAbsent(playerId, () => 0);
    _streakByPlayer.putIfAbsent(playerId, () => 0);
    _bestStreakByPlayer.putIfAbsent(playerId, () => 0);
    _hitsByPlayer.putIfAbsent(playerId, () => 0);
    _missesByPlayer.putIfAbsent(playerId, () => 0);
  }

  void _advanceResolvedBall(BasketballBall ball, double dt) {
    _physics.advanceResolvedBall(ball, dt);
  }

  bool _isBallBelowScreen(BasketballBall ball) {
    final projected = BasketballProjector(
      _arenaSize,
    ).projectBall(ball.courtPosition, baseRadius: ball.radius);
    return projected.center.dy > _arenaSize.height + projected.radius * 2.2;
  }

  String _missLabel(BasketballMissType missType) {
    return switch (missType) {
      BasketballMissType.short => 'Short',
      BasketballMissType.long => 'Long',
      BasketballMissType.left => 'Left',
      BasketballMissType.right => 'Right',
      BasketballMissType.rimOut => 'Rim out',
      BasketballMissType.backboardOut => 'Backboard',
      BasketballMissType.timeout => 'No basket',
      BasketballMissType.outOfBounds => 'Out',
    };
  }
}
