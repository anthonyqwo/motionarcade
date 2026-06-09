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
  }) : players = List.from(initialPlayers) {
    _eventSub = server.events.listen(_handleEvent);
    _motionEventSub = motionEvents?.listen(_handleEvent);
  }

  final WebSocketServerService server;
  final List<Player> players;
  final List<SaberTarget> targets = [];
  final ScoringSystem scoring = ScoringSystem();
  final TrailPointBuffer _trailBuffer = TrailPointBuffer();

  StreamSubscription? _eventSub;
  StreamSubscription? _motionEventSub;
  double speed = 0.38; // depth units per second
  int _targetCounter = 0;
  double _elapsedTime = 0.0;
  double _lastSpawnTime = 0.0;
  final double _spawnIntervalSeconds = 2.5;

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

    // Check if we should spawn a target
    if (_elapsedTime - _lastSpawnTime >= _spawnIntervalSeconds) {
      _spawnTarget(now);
      _lastSpawnTime = _elapsedTime;
      needsNotify = true;
    }

    // Update targets
    for (final target in List<SaberTarget>.from(targets)) {
      target.update(dt, speed);

      // If a target is active and passes depth 1.0 without being hit, it's a Miss!
      if (target.status == SaberTargetStatus.active && target.depth >= 1.0) {
        target.status = SaberTargetStatus.missed;
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
    targets.removeWhere((t) {
      if (t.isCut && t.cutProgress >= 1.0) return true;
      if (t.status == SaberTargetStatus.missed &&
          now.difference(t.spawnTime).inSeconds > 5) {
        return true;
      }
      return false;
    });

    _trailBuffer.prune(now);

    if (needsNotify) {
      notifyListeners();
    }
  }

  void _spawnTarget(DateTime now) {
    _targetCounter++;
    final random = math.Random();

    final directions = [
      MotionDirection.up,
      MotionDirection.down,
      MotionDirection.left,
      MotionDirection.right,
    ];
    final direction = directions[random.nextInt(directions.length)];

    final lanes = [-1.0, 0.0, 1.0];
    final lane = lanes[random.nextInt(lanes.length)];

    targets.add(
      SaberTarget(
        id: 'target_$_targetCounter',
        direction: direction,
        lane: lane,
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
        closestTarget.status = SaberTargetStatus.missed;
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
