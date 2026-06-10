import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import '../../network/websocket_server_service.dart';
import '../../shared/models/motion_event.dart';
import '../../shared/models/player.dart';
import '../../shared/scoring/scoring_system.dart';
import '../../shared/visual/trail_point_buffer.dart';
import '../../shared/visual/trail_renderer.dart';
import 'saber_target.dart';

enum SaberRunPhase { countdown, playing, gameOver }

enum SaberGameOverReason { outOfLives }

class SaberHitEffect {
  const SaberHitEffect({
    required this.slash,
    required this.targetId,
    required this.targetDirection,
    required this.result,
    required this.addedScore,
  });

  final SlashEvent slash;
  final String targetId;
  final MotionDirection targetDirection;
  final FeedbackResult result;
  final int addedScore;
}

class SaberPlayerStats {
  const SaberPlayerStats({
    required this.player,
    required this.score,
    required this.combo,
    required this.maxCombo,
    required this.multiplier,
    required this.hits,
    required this.misses,
  });

  final Player player;
  final int score;
  final int combo;
  final int maxCombo;
  final double multiplier;
  final int hits;
  final int misses;
}

class SaberGameState extends ChangeNotifier {
  SaberGameState({
    required this.server,
    required List<Player> initialPlayers,
    Stream<MotionEvent>? motionEvents,
    math.Random? random,
    double countdownSeconds = _defaultCountdownSeconds,
  }) : players = List.from(initialPlayers),
       _random = random,
       _phase = countdownSeconds > 0
           ? SaberRunPhase.countdown
           : SaberRunPhase.playing,
       _countdownRemaining = countdownSeconds,
       _sharedLives = _initialSharedLives {
    _eventSub = server.events.listen(_handleEvent);
    _motionEventSub = motionEvents?.listen(_handleEvent);
    for (final player in players) {
      scoringForPlayer(player.id);
    }
  }

  static const int _initialSharedLives = 3;
  static const double _defaultCountdownSeconds = 3.0;

  static const List<({double lane, double row})> _spawnPositions = [
    (lane: -0.95, row: -0.55),
    (lane: 0.0, row: -0.62),
    (lane: 0.95, row: -0.55),
    (lane: -1.1, row: -0.08),
    (lane: -0.42, row: 0.0),
    (lane: 0.42, row: 0.0),
    (lane: 1.1, row: -0.08),
    (lane: -0.78, row: 0.48),
    (lane: 0.0, row: 0.55),
    (lane: 0.78, row: 0.48),
  ];

  final WebSocketServerService server;
  final List<Player> players;
  final List<SaberTarget> targets = [];
  final TrailPointBuffer _trailBuffer = TrailPointBuffer();
  final Map<String, ScoringSystem> _scoringByPlayer = {};
  final Map<String, int> _hitsByPlayer = {};
  final Map<String, int> _missesByPlayer = {};
  math.Random? _random;

  StreamSubscription? _eventSub;
  StreamSubscription? _motionEventSub;
  double speed = 0.48; // depth units per second
  int _targetCounter = 0;
  double _elapsedTime = 0.0;
  double _lastSpawnTime = 0.0;
  final double _spawnIntervalSeconds = 1.65;
  int? _lastSpawnPositionIndex;
  SaberRunPhase? _phase;
  SaberGameOverReason? _gameOverReason;
  double? _countdownRemaining;
  double? _survivedSeconds;
  int? _sharedLives;
  int? _teamMisses;

  SlashEvent? lastSlash;
  SaberHitEffect? lastHitEffect;
  String lastEventLabel = 'none';
  List<TrailRenderPoint> get trailPoints => _trailBuffer.points;
  SaberRunPhase get phase => _phase ?? SaberRunPhase.playing;
  SaberGameOverReason? get gameOverReason => _gameOverReason;
  int get sharedLives => _sharedLives ?? _initialSharedLives;
  int get maxSharedLives => _initialSharedLives;
  int get teamMisses => _teamMisses ?? 0;
  double get countdownRemaining => (_countdownRemaining ?? 0).clamp(0.0, 99.0);
  double get survivedSeconds => _survivedSeconds ?? 0.0;
  bool get isPlaying => phase == SaberRunPhase.playing;
  bool get isGameOver => phase == SaberRunPhase.gameOver;

  ScoringSystem get scoring {
    final playerId = players.isEmpty ? 'solo' : players.first.id;
    return scoringForPlayer(playerId);
  }

  List<SaberPlayerStats> get playerStats {
    return [
      for (final player in players)
        SaberPlayerStats(
          player: player,
          score: scoringForPlayer(player.id).score,
          combo: scoringForPlayer(player.id).combo,
          maxCombo: scoringForPlayer(player.id).maxCombo,
          multiplier: scoringForPlayer(player.id).multiplier,
          hits: _hitsByPlayer[player.id] ?? 0,
          misses: _missesByPlayer[player.id] ?? 0,
        ),
    ]..sort((a, b) => b.score.compareTo(a.score));
  }

  ScoringSystem scoringForPlayer(String playerId) {
    return _scoringByPlayer.putIfAbsent(playerId, ScoringSystem.new);
  }

  void restartRun({double countdownSeconds = _defaultCountdownSeconds}) {
    targets.clear();
    _trailBuffer.clear();
    for (final scoring in _scoringByPlayer.values) {
      scoring.reset();
    }
    _hitsByPlayer.clear();
    _missesByPlayer.clear();
    _sharedLives = _initialSharedLives;
    _teamMisses = 0;
    _survivedSeconds = 0.0;
    _elapsedTime = 0.0;
    _lastSpawnTime = 0.0;
    _targetCounter = 0;
    _lastSpawnPositionIndex = null;
    _gameOverReason = null;
    _countdownRemaining = countdownSeconds;
    _phase = countdownSeconds > 0
        ? SaberRunPhase.countdown
        : SaberRunPhase.playing;
    lastSlash = null;
    lastHitEffect = null;
    lastEventLabel = 'restart';
    notifyListeners();
  }

  @override
  void dispose() {
    _eventSub?.cancel();
    _motionEventSub?.cancel();
    super.dispose();
  }

  void update(double dt) {
    _elapsedTime += dt;
    final now = DateTime.now();
    bool needsNotify = false;
    var playingDt = isPlaying ? dt : 0.0;

    if (phase == SaberRunPhase.countdown) {
      final previousCountdown = countdownRemaining;
      _countdownRemaining = countdownRemaining - dt;
      if (countdownRemaining <= 0) {
        _phase = SaberRunPhase.playing;
        _countdownRemaining = 0;
        _lastSpawnTime = _elapsedTime - _spawnIntervalSeconds;
        playingDt = math.max(0.0, dt - previousCountdown);
      }
      needsNotify = true;
    }

    if (playingDt > 0) {
      _survivedSeconds = survivedSeconds + playingDt;
    }

    for (final target in List<SaberTarget>.from(targets)) {
      target.update(dt, speed);

      if (isPlaying &&
          target.status == SaberTargetStatus.active &&
          target.depth >= 1.0) {
        target.markMissed();
        _registerSharedMiss(message: 'Missed target!');
        needsNotify = true;
      }
    }

    targets.removeWhere((t) => t.isFinished);

    _trailBuffer.prune(now);

    if (isPlaying && _elapsedTime - _lastSpawnTime >= _spawnIntervalSeconds) {
      _spawnTarget(now);
      _lastSpawnTime = _elapsedTime;
      needsNotify = true;
    }

    if (needsNotify) {
      notifyListeners();
    }
  }

  void _spawnTarget(DateTime now) {
    _targetCounter++;

    final directions = [
      MotionDirection.up,
      MotionDirection.down,
      MotionDirection.left,
      MotionDirection.right,
    ];
    final random = _random ??= math.Random();
    final direction = directions[random.nextInt(directions.length)];

    var positionIndex = random.nextInt(_spawnPositions.length);
    final lastIndex = _lastSpawnPositionIndex;
    if (lastIndex != null &&
        positionIndex == lastIndex &&
        _spawnPositions.length > 1) {
      positionIndex = (positionIndex + 1) % _spawnPositions.length;
    }
    _lastSpawnPositionIndex = positionIndex;
    final position = _spawnPositions[positionIndex];

    targets.add(
      SaberTarget(
        id: 'target_$_targetCounter',
        direction: direction,
        lane: position.lane,
        row: position.row,
        spawnTime: now,
        depth: 0.0,
      ),
    );
  }

  void _handleEvent(MotionEvent event) {
    if (event is JoinEvent) {
      _handleJoin(event);
    } else if (event is DisconnectEvent) {
      _handleDisconnect(event);
    } else if (event is SlashEvent) {
      _handleSlash(event);
    } else if (event is MotionTrailEvent) {
      _handleMotionTrail(event);
    }
  }

  void _handleJoin(JoinEvent event) {
    final index = players.indexWhere((p) => p.id == event.playerId);
    final p = Player(
      id: event.playerId,
      name: event.name,
      deviceLabel: event.device,
      status: PlayerConnectionStatus.connected,
    );
    if (index == -1) {
      players.add(p);
    } else {
      players[index] = p;
    }
    scoringForPlayer(event.playerId);
    lastEventLabel = 'Join: ${event.name}';
    notifyListeners();
  }

  void _handleDisconnect(DisconnectEvent event) {
    final index = players.indexWhere((p) => p.id == event.playerId);
    if (index != -1) {
      final p = players[index];
      players[index] = Player(
        id: p.id,
        name: p.name,
        deviceLabel: p.deviceLabel,
        status: PlayerConnectionStatus.disconnected,
      );
      lastEventLabel = 'Disconnect: ${p.name}';
    }
    notifyListeners();
  }

  void _handleMotionTrail(MotionTrailEvent event) {
    _trailBuffer.addEvent(event);
  }

  void _handleSlash(SlashEvent event) {
    if (!isPlaying) {
      return;
    }

    lastEventLabel = 'Slash: ${event.direction.name}';

    SaberTarget? closestTarget;
    double maxDepth = -1.0;

    for (final target in targets) {
      if (target.status == SaberTargetStatus.active &&
          target.depth >= 0.75 &&
          target.depth <= 1.0) {
        if (target.depth > maxDepth) {
          maxDepth = target.depth;
          closestTarget = target;
        }
      }
    }

    if (closestTarget != null) {
      final isMatch = event.direction == closestTarget.direction;
      if (isMatch) {
        lastSlash = event;
        FeedbackResult rating;
        SaberTargetStatus cutStatus;
        HapticPattern haptic;
        String message;
        int duration;

        if (closestTarget.depth >= 0.92) {
          rating = FeedbackResult.perfect;
          cutStatus = SaberTargetStatus.cutPerfect;
          haptic = HapticPattern.perfect;
          message = 'Perfect Slash!';
          duration = 100;
        } else if (closestTarget.depth >= 0.84) {
          rating = FeedbackResult.good;
          cutStatus = SaberTargetStatus.cutGood;
          haptic = HapticPattern.good;
          message = 'Good Slash!';
          duration = 80;
        } else {
          rating = FeedbackResult.weak;
          cutStatus = SaberTargetStatus.cutWeak;
          haptic = HapticPattern.medium;
          message = 'Weak Slash!';
          duration = 60;
        }

        closestTarget.status = cutStatus;
        closestTarget.cutAngle = switch (event.direction) {
          MotionDirection.up || MotionDirection.down => 0.0,
          MotionDirection.left || MotionDirection.right => math.pi / 2,
          _ => math.pi / 4,
        };

        final addedScore = scoringForPlayer(event.playerId).registerHit(rating);
        lastHitEffect = SaberHitEffect(
          slash: event,
          targetId: closestTarget.id,
          targetDirection: closestTarget.direction,
          result: rating,
          addedScore: addedScore,
        );
        _hitsByPlayer[event.playerId] =
            (_hitsByPlayer[event.playerId] ?? 0) + 1;

        server.sendToPlayer(
          event.playerId,
          FeedbackEvent(
            playerId: event.playerId,
            timestamp: DateTime.now(),
            result: rating,
            haptic: haptic,
            durationMs: duration,
            message: message,
          ),
        );
      } else {
        closestTarget.markMissed();
        _registerSharedMiss(
          playerId: event.playerId,
          message: 'Wrong direction!',
          broadcast: false,
        );

        server.sendToPlayer(
          event.playerId,
          FeedbackEvent(
            playerId: event.playerId,
            timestamp: DateTime.now(),
            result: FeedbackResult.miss,
            haptic: HapticPattern.miss,
            durationMs: 150,
            message: 'Wrong direction!',
          ),
        );
      }
    }
    notifyListeners();
  }

  void _registerSharedMiss({
    String? playerId,
    required String message,
    bool broadcast = true,
  }) {
    if (!isPlaying) {
      return;
    }

    _teamMisses = teamMisses + 1;
    _sharedLives = math.max(0, sharedLives - 1);

    if (playerId != null) {
      scoringForPlayer(playerId).registerHit(FeedbackResult.miss);
      _missesByPlayer[playerId] = (_missesByPlayer[playerId] ?? 0) + 1;
    }

    if (broadcast) {
      _sendFeedbackToAll(
        result: FeedbackResult.miss,
        haptic: HapticPattern.miss,
        message: message,
        durationMs: 150,
      );
    }

    lastEventLabel = message;
    if (sharedLives <= 0) {
      _phase = SaberRunPhase.gameOver;
      _gameOverReason = SaberGameOverReason.outOfLives;
      lastEventLabel = 'Game over';
    }
  }

  void _sendFeedbackToAll({
    required FeedbackResult result,
    required HapticPattern haptic,
    required String message,
    required int durationMs,
  }) {
    for (final player in players) {
      if (player.status == PlayerConnectionStatus.connected) {
        server.sendToPlayer(
          player.id,
          FeedbackEvent(
            playerId: player.id,
            timestamp: DateTime.now(),
            result: result,
            haptic: haptic,
            durationMs: durationMs,
            message: message,
          ),
        );
      }
    }
  }
}
