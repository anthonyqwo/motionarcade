import 'motion_trail_sample.dart';

sealed class MotionEvent {
  const MotionEvent({
    required this.type,
    required this.playerId,
    required this.timestamp,
    this.version = 1,
  });

  final String type;
  final String playerId;
  final DateTime timestamp;
  final int version;

  Map<String, Object?> toJson();
}

class JoinEvent extends MotionEvent {
  const JoinEvent({
    required super.playerId,
    required super.timestamp,
    required this.name,
    required this.device,
  }) : super(type: 'join');

  final String name;
  final String device;

  @override
  Map<String, Object?> toJson() {
    return {
      'version': version,
      'type': type,
      'playerId': playerId,
      'name': name,
      'device': device,
      'timestamp': timestamp.millisecondsSinceEpoch,
    };
  }
}

class ButtonEvent extends MotionEvent {
  const ButtonEvent({
    required super.playerId,
    required super.timestamp,
    required this.button,
    this.pressed = true,
  }) : super(type: 'button');

  final String button;
  final bool pressed;

  @override
  Map<String, Object?> toJson() {
    return {
      'version': version,
      'type': type,
      'playerId': playerId,
      'button': button,
      'pressed': pressed,
      'timestamp': timestamp.millisecondsSinceEpoch,
    };
  }
}

class CalibrateEvent extends MotionEvent {
  const CalibrateEvent({
    required super.playerId,
    required super.timestamp,
    required this.neutral,
  }) : super(type: 'calibrate');

  final NeutralPosition neutral;

  @override
  Map<String, Object?> toJson() {
    return {
      'version': version,
      'type': type,
      'playerId': playerId,
      'neutral': neutral.toJson(),
      'timestamp': timestamp.millisecondsSinceEpoch,
    };
  }
}

class SwingEvent extends MotionEvent {
  const SwingEvent({
    required super.playerId,
    required super.timestamp,
    required this.direction,
    required this.power,
    required this.durationMs,
  }) : super(type: 'swing');

  final MotionDirection direction;
  final double power;
  final int durationMs;

  @override
  Map<String, Object?> toJson() {
    return {
      'version': version,
      'type': type,
      'playerId': playerId,
      'direction': direction.name,
      'power': power,
      'durationMs': durationMs,
      'timestamp': timestamp.millisecondsSinceEpoch,
    };
  }
}

class SlashEvent extends MotionEvent {
  const SlashEvent({
    required super.playerId,
    required super.timestamp,
    required this.direction,
    required this.power,
    required this.durationMs,
  }) : super(type: 'slash');

  final MotionDirection direction;
  final double power;
  final int durationMs;

  @override
  Map<String, Object?> toJson() {
    return {
      'version': version,
      'type': type,
      'playerId': playerId,
      'direction': direction.name,
      'power': power,
      'durationMs': durationMs,
      'timestamp': timestamp.millisecondsSinceEpoch,
    };
  }
}

class ShootEvent extends MotionEvent {
  const ShootEvent({
    required super.playerId,
    required super.timestamp,
    required this.power,
    required this.angle,
    required this.offset,
    required this.stability,
    required this.holdDurationMs,
  }) : super(type: 'shoot');

  final double power;
  final double angle;
  final double offset;
  final double stability;
  final int holdDurationMs;

  @override
  Map<String, Object?> toJson() {
    return {
      'version': version,
      'type': type,
      'playerId': playerId,
      'power': power,
      'angle': angle,
      'offset': offset,
      'stability': stability,
      'holdDurationMs': holdDurationMs,
      'timestamp': timestamp.millisecondsSinceEpoch,
    };
  }
}

class ShootHoldEvent extends MotionEvent {
  const ShootHoldEvent({
    required super.playerId,
    required super.timestamp,
    this.pressed = true,
  }) : super(type: 'shootHold');

  final bool pressed;

  @override
  Map<String, Object?> toJson() {
    return {
      'version': version,
      'type': type,
      'playerId': playerId,
      'pressed': pressed,
      'timestamp': timestamp.millisecondsSinceEpoch,
    };
  }
}

class MotionTrailEvent extends MotionEvent {
  const MotionTrailEvent({
    required super.playerId,
    required super.timestamp,
    required this.samples,
    required this.referenceTimestamp,
  }) : super(type: 'motionTrail');

  final List<MotionTrailSample> samples;
  final DateTime referenceTimestamp;

  @override
  Map<String, Object?> toJson() {
    return {
      'version': version,
      'type': type,
      'playerId': playerId,
      'samples': samples.map((s) => s.toJson()).toList(),
      'referenceTimestamp': referenceTimestamp.millisecondsSinceEpoch,
      'timestamp': timestamp.millisecondsSinceEpoch,
    };
  }
}

class FeedbackEvent extends MotionEvent {
  const FeedbackEvent({
    required super.playerId,
    required super.timestamp,
    required this.result,
    required this.haptic,
    required this.durationMs,
    this.message,
  }) : super(type: 'feedback');

  final FeedbackResult result;
  final HapticPattern haptic;
  final int durationMs;
  final String? message;

  @override
  Map<String, Object?> toJson() {
    return {
      'version': version,
      'type': type,
      'playerId': playerId,
      'result': result.name,
      'haptic': haptic.name,
      'durationMs': durationMs,
      if (message != null) 'message': message,
      'timestamp': timestamp.millisecondsSinceEpoch,
    };
  }
}

class TransportConfigEvent extends MotionEvent {
  const TransportConfigEvent({
    required super.playerId,
    required super.timestamp,
    required this.udpHost,
    required this.udpPort,
    required this.roomToken,
    this.trailRateHz = 30,
    this.maxBatchSize = 6,
  }) : super(type: 'transportConfig');

  final String udpHost;
  final int udpPort;
  final String roomToken;
  final int trailRateHz;
  final int maxBatchSize;

  @override
  Map<String, Object?> toJson() {
    return {
      'version': version,
      'type': type,
      'playerId': playerId,
      'udpHost': udpHost,
      'udpPort': udpPort,
      'roomToken': roomToken,
      'trailRateHz': trailRateHz,
      'maxBatchSize': maxBatchSize,
      'timestamp': timestamp.millisecondsSinceEpoch,
    };
  }
}

class GameCommandEvent extends MotionEvent {
  const GameCommandEvent({
    required super.playerId,
    required super.timestamp,
    required this.command,
    this.gameId,
    this.requestId,
  }) : super(type: 'gameCommand');

  final GameCommand command;
  final GameId? gameId;
  final String? requestId;

  @override
  Map<String, Object?> toJson() {
    return {
      'version': version,
      'type': type,
      'playerId': playerId,
      'command': command.name,
      if (gameId != null) 'gameId': gameId!.name,
      if (requestId != null) 'requestId': requestId,
      'timestamp': timestamp.millisecondsSinceEpoch,
    };
  }
}

class RoomStateEvent extends MotionEvent {
  const RoomStateEvent({
    required super.playerId,
    required super.timestamp,
    required this.selectedGame,
    required this.availableGames,
    required this.roomPhase,
    required this.playerScores,
    required this.connectedPlayers,
    required this.canStart,
    required this.canRestart,
    required this.canBackToRoom,
    this.sharedLives = 0,
    this.maxSharedLives = 0,
    this.survivedSeconds = 0,
    this.message,
  }) : super(type: 'roomState');

  final GameId selectedGame;
  final List<GameId> availableGames;
  final RoomPhase roomPhase;
  final List<PlayerScoreSnapshot> playerScores;
  final int connectedPlayers;
  final bool canStart;
  final bool canRestart;
  final bool canBackToRoom;
  final int sharedLives;
  final int maxSharedLives;
  final double survivedSeconds;
  final String? message;

  PlayerScoreSnapshot? scoreForPlayer(String playerId) {
    for (final score in playerScores) {
      if (score.playerId == playerId) {
        return score;
      }
    }
    return null;
  }

  @override
  Map<String, Object?> toJson() {
    return {
      'version': version,
      'type': type,
      'playerId': playerId,
      'selectedGame': selectedGame.name,
      'availableGames': availableGames.map((game) => game.name).toList(),
      'roomPhase': roomPhase.name,
      'playerScores': playerScores.map((score) => score.toJson()).toList(),
      'connectedPlayers': connectedPlayers,
      'canStart': canStart,
      'canRestart': canRestart,
      'canBackToRoom': canBackToRoom,
      'sharedLives': sharedLives,
      'maxSharedLives': maxSharedLives,
      'survivedSeconds': survivedSeconds,
      if (message != null) 'message': message,
      'timestamp': timestamp.millisecondsSinceEpoch,
    };
  }
}

class PlayerScoreSnapshot {
  const PlayerScoreSnapshot({
    required this.playerId,
    required this.name,
    required this.score,
    required this.combo,
    required this.maxCombo,
    required this.hits,
    required this.misses,
    required this.rank,
    this.connected = true,
  });

  final String playerId;
  final String name;
  final int score;
  final int combo;
  final int maxCombo;
  final int hits;
  final int misses;
  final int rank;
  final bool connected;

  Map<String, Object?> toJson() {
    return {
      'playerId': playerId,
      'name': name,
      'score': score,
      'combo': combo,
      'maxCombo': maxCombo,
      'hits': hits,
      'misses': misses,
      'rank': rank,
      'connected': connected,
    };
  }
}

class DisconnectEvent extends MotionEvent {
  const DisconnectEvent({required super.playerId, required super.timestamp})
    : super(type: 'disconnect');

  @override
  Map<String, Object?> toJson() {
    return {
      'version': version,
      'type': type,
      'playerId': playerId,
      'timestamp': timestamp.millisecondsSinceEpoch,
    };
  }
}

class UnknownMotionEvent extends MotionEvent {
  const UnknownMotionEvent({
    required super.type,
    required super.playerId,
    required super.timestamp,
    required this.payload,
  });

  final Map<String, Object?> payload;

  @override
  Map<String, Object?> toJson() => payload;
}

enum MotionDirection { left, right, up, down, forward, backward }

class NeutralPosition {
  const NeutralPosition({
    required this.pitch,
    required this.roll,
    required this.yaw,
  });

  final double pitch;
  final double roll;
  final double yaw;

  Map<String, Object?> toJson() {
    return {'pitch': pitch, 'roll': roll, 'yaw': yaw};
  }
}

enum FeedbackResult { perfect, good, weak, miss }

enum HapticPattern { light, medium, strong, long, combo, perfect, good, miss }

enum GameId { motionSaber, basketball, pingPong }

enum RoomPhase { lobby, countdown, playing, gameOver }

enum GameCommand { selectGame, startGame, restartGame, backToRoom }

extension MotionEventNormalization on MotionEvent {
  MotionEvent normalized(DateTime now) {
    final self = this;
    if (self is JoinEvent) {
      return JoinEvent(
        playerId: self.playerId,
        timestamp: now,
        name: self.name,
        device: self.device,
      );
    } else if (self is DisconnectEvent) {
      return DisconnectEvent(playerId: self.playerId, timestamp: now);
    } else if (self is ButtonEvent) {
      return ButtonEvent(
        playerId: self.playerId,
        timestamp: now,
        button: self.button,
        pressed: self.pressed,
      );
    } else if (self is CalibrateEvent) {
      return CalibrateEvent(
        playerId: self.playerId,
        timestamp: now,
        neutral: self.neutral,
      );
    } else if (self is SwingEvent) {
      return SwingEvent(
        playerId: self.playerId,
        timestamp: now,
        direction: self.direction,
        power: self.power,
        durationMs: self.durationMs,
      );
    } else if (self is SlashEvent) {
      return SlashEvent(
        playerId: self.playerId,
        timestamp: now,
        direction: self.direction,
        power: self.power,
        durationMs: self.durationMs,
      );
    } else if (self is ShootEvent) {
      return ShootEvent(
        playerId: self.playerId,
        timestamp: now,
        power: self.power,
        angle: self.angle,
        offset: self.offset,
        stability: self.stability,
        holdDurationMs: self.holdDurationMs,
      );
    } else if (self is ShootHoldEvent) {
      return ShootHoldEvent(
        playerId: self.playerId,
        timestamp: now,
        pressed: self.pressed,
      );
    } else if (self is MotionTrailEvent) {
      final lastSampleTMs = self.samples.isNotEmpty ? self.samples.last.tMs : 0;
      final normalizedRef = now.subtract(Duration(milliseconds: lastSampleTMs));
      return MotionTrailEvent(
        playerId: self.playerId,
        timestamp: now,
        referenceTimestamp: normalizedRef,
        samples: self.samples,
      );
    } else if (self is FeedbackEvent) {
      return FeedbackEvent(
        playerId: self.playerId,
        timestamp: now,
        result: self.result,
        haptic: self.haptic,
        durationMs: self.durationMs,
        message: self.message,
      );
    } else if (self is TransportConfigEvent) {
      return TransportConfigEvent(
        playerId: self.playerId,
        timestamp: now,
        udpHost: self.udpHost,
        udpPort: self.udpPort,
        roomToken: self.roomToken,
        trailRateHz: self.trailRateHz,
        maxBatchSize: self.maxBatchSize,
      );
    } else if (self is GameCommandEvent) {
      return GameCommandEvent(
        playerId: self.playerId,
        timestamp: now,
        command: self.command,
        gameId: self.gameId,
        requestId: self.requestId,
      );
    } else if (self is RoomStateEvent) {
      return RoomStateEvent(
        playerId: self.playerId,
        timestamp: now,
        selectedGame: self.selectedGame,
        availableGames: self.availableGames,
        roomPhase: self.roomPhase,
        playerScores: self.playerScores,
        connectedPlayers: self.connectedPlayers,
        canStart: self.canStart,
        canRestart: self.canRestart,
        canBackToRoom: self.canBackToRoom,
        sharedLives: self.sharedLives,
        maxSharedLives: self.maxSharedLives,
        survivedSeconds: self.survivedSeconds,
        message: self.message,
      );
    }
    return this;
  }
}
