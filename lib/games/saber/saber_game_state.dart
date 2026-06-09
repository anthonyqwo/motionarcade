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

class SaberGameState extends ChangeNotifier {
  SaberGameState({
    required this.server,
    required List<Player> initialPlayers,
    Stream<MotionEvent>? motionEvents,
    math.Random? random,
  }) : players = List.from(initialPlayers),
       _random = random {
    _eventSub = server.events.listen(_handleEvent);
    _motionEventSub = motionEvents?.listen(_handleEvent);
  }

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
  final ScoringSystem scoring = ScoringSystem();
  final TrailPointBuffer _trailBuffer = TrailPointBuffer();
  math.Random? _random;

  StreamSubscription? _eventSub;
  StreamSubscription? _motionEventSub;
  double speed = 0.48; // depth units per second
  int _targetCounter = 0;
  double _elapsedTime = 0.0;
  double _lastSpawnTime = 0.0;
  final double _spawnIntervalSeconds = 1.65;
  int? _lastSpawnPositionIndex;

  SlashEvent? lastSlash;
  String lastEventLabel = 'none';
  List<TrailRenderPoint> get trailPoints => _trailBuffer.points;

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

    // Update targets
    for (final target in List<SaberTarget>.from(targets)) {
      target.update(dt, speed);

      // If a target is active and passes depth 1.0 without being hit, it's a Miss!
      if (target.status == SaberTargetStatus.active && target.depth >= 1.0) {
        target.markMissed();
        scoring.registerHit(FeedbackResult.miss);
        needsNotify = true;

        _sendFeedbackToAll(
          result: FeedbackResult.miss,
          haptic: HapticPattern.miss,
          message: 'Missed target!',
          durationMs: 150,
        );
      }
    }

    // Clean up targets that are finished animating or missed
    targets.removeWhere((t) => t.isFinished);

    _trailBuffer.prune(now);

    // Check if we should spawn a target after updating existing targets so new
    // targets do not jump forward by a whole frame interval.
    if (_elapsedTime - _lastSpawnTime >= _spawnIntervalSeconds) {
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

        scoring.registerHit(rating);

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
        scoring.registerHit(FeedbackResult.miss);

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
