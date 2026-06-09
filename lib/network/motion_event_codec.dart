import 'dart:convert';

import '../shared/models/motion_event.dart';
import '../shared/models/motion_trail_sample.dart';

class MotionEventCodec {
  const MotionEventCodec();

  String encode(MotionEvent event) => jsonEncode(event.toJson());

  MotionEvent decode(String source) {
    final decoded = jsonDecode(source);
    if (decoded is! Map<String, Object?>) {
      throw const FormatException(
        'Motion event payload must be a JSON object.',
      );
    }

    return fromJson(decoded);
  }

  MotionEvent fromJson(Map<String, Object?> json) {
    final type = _readString(json, 'type', fallback: 'unknown');
    final playerId = _readString(json, 'playerId', fallback: 'unknown-player');
    final timestamp = _readTimestamp(json['timestamp']);

    return switch (type) {
      'join' => JoinEvent(
        playerId: playerId,
        timestamp: timestamp,
        name: _readString(json, 'name', fallback: 'Player'),
        device: _readString(json, 'device', fallback: 'unknown'),
      ),
      'disconnect' => DisconnectEvent(playerId: playerId, timestamp: timestamp),
      'button' => ButtonEvent(
        playerId: playerId,
        timestamp: timestamp,
        button: _readString(json, 'button', fallback: 'unknown'),
        pressed: _readBool(json, 'pressed', fallback: true),
      ),
      'calibrate' => CalibrateEvent(
        playerId: playerId,
        timestamp: timestamp,
        neutral: _readNeutral(json['neutral']),
      ),
      'swing' => SwingEvent(
        playerId: playerId,
        timestamp: timestamp,
        direction: _readDirection(json['direction']),
        power: _readDouble(json, 'power', fallback: 0),
        durationMs: _readInt(json, 'durationMs', fallback: 0),
      ),
      'slash' => SlashEvent(
        playerId: playerId,
        timestamp: timestamp,
        direction: _readDirection(json['direction']),
        power: _readDouble(json, 'power', fallback: 0),
        durationMs: _readInt(json, 'durationMs', fallback: 0),
      ),
      'shoot' => ShootEvent(
        playerId: playerId,
        timestamp: timestamp,
        power: _readDouble(json, 'power', fallback: 0),
        angle: _readDouble(json, 'angle', fallback: 0),
        offset: _readDouble(json, 'offset', fallback: 0),
        stability: _readDouble(json, 'stability', fallback: 0),
        holdDurationMs: _readInt(json, 'holdDurationMs', fallback: 0),
      ),
      'shootHold' => ShootHoldEvent(
        playerId: playerId,
        timestamp: timestamp,
        pressed: _readBool(json, 'pressed', fallback: true),
      ),
      'motionTrail' => MotionTrailEvent(
        playerId: playerId,
        timestamp: timestamp,
        referenceTimestamp: _readTimestamp(json['referenceTimestamp']),
        samples: (json['samples'] as List? ?? [])
            .map(
              (s) => s is Map<String, Object?>
                  ? MotionTrailSample.fromJson(s)
                  : MotionTrailSample.fromJson(
                      Map<String, Object?>.from(s as Map),
                    ),
            )
            .toList(),
      ),
      'feedback' => FeedbackEvent(
        playerId: playerId,
        timestamp: timestamp,
        result: _readFeedbackResult(json['result']),
        haptic: _readHapticPattern(json['haptic']),
        durationMs: _readInt(json, 'durationMs', fallback: 0),
        message: _readOptionalString(json['message']),
      ),
      'transportConfig' => TransportConfigEvent(
        playerId: playerId,
        timestamp: timestamp,
        udpHost: _readString(json, 'udpHost', fallback: ''),
        udpPort: _readInt(json, 'udpPort', fallback: 0),
        roomToken: _readString(json, 'roomToken', fallback: ''),
        trailRateHz: _readInt(json, 'trailRateHz', fallback: 30),
        maxBatchSize: _readInt(json, 'maxBatchSize', fallback: 6),
      ),
      'gameCommand' => GameCommandEvent(
        playerId: playerId,
        timestamp: timestamp,
        command: _readGameCommand(json['command']),
        gameId: _readOptionalGameId(json['gameId']),
        requestId: _readOptionalString(json['requestId']),
      ),
      'roomState' => RoomStateEvent(
        playerId: playerId,
        timestamp: timestamp,
        selectedGame: _readGameId(json['selectedGame']),
        availableGames: _readGameIds(json['availableGames']),
        roomPhase: _readRoomPhase(json['roomPhase']),
        playerScores: _readPlayerScores(json['playerScores']),
        connectedPlayers: _readInt(json, 'connectedPlayers', fallback: 0),
        canStart: _readBool(json, 'canStart', fallback: false),
        canRestart: _readBool(json, 'canRestart', fallback: false),
        canBackToRoom: _readBool(json, 'canBackToRoom', fallback: false),
        sharedLives: _readInt(json, 'sharedLives', fallback: 0),
        maxSharedLives: _readInt(json, 'maxSharedLives', fallback: 0),
        survivedSeconds: _readDouble(json, 'survivedSeconds', fallback: 0),
        message: _readOptionalString(json['message']),
      ),
      _ => UnknownMotionEvent(
        type: type,
        playerId: playerId,
        timestamp: timestamp,
        payload: json,
      ),
    };
  }

  String? _readOptionalString(Object? value) {
    return value is String && value.isNotEmpty ? value : null;
  }

  String _readString(
    Map<String, Object?> json,
    String key, {
    required String fallback,
  }) {
    final value = json[key];
    return value is String && value.isNotEmpty ? value : fallback;
  }

  bool _readBool(
    Map<String, Object?> json,
    String key, {
    required bool fallback,
  }) {
    final value = json[key];
    return value is bool ? value : fallback;
  }

  int _readInt(Map<String, Object?> json, String key, {required int fallback}) {
    final value = json[key];
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.round();
    }
    return fallback;
  }

  double _readDouble(
    Map<String, Object?> json,
    String key, {
    required double fallback,
  }) {
    final value = json[key];
    return value is num ? value.toDouble() : fallback;
  }

  DateTime _readTimestamp(Object? value) {
    if (value is int) {
      return DateTime.fromMillisecondsSinceEpoch(value);
    }
    if (value is num) {
      return DateTime.fromMillisecondsSinceEpoch(value.round());
    }
    if (value is String) {
      return DateTime.tryParse(value) ?? DateTime.fromMillisecondsSinceEpoch(0);
    }
    return DateTime.fromMillisecondsSinceEpoch(0);
  }

  MotionDirection _readDirection(Object? value) {
    if (value is String) {
      for (final direction in MotionDirection.values) {
        if (direction.name == value) {
          return direction;
        }
      }
    }
    return MotionDirection.down;
  }

  NeutralPosition _readNeutral(Object? value) {
    if (value is Map<String, Object?>) {
      return NeutralPosition(
        pitch: _readDouble(value, 'pitch', fallback: 0),
        roll: _readDouble(value, 'roll', fallback: 0),
        yaw: _readDouble(value, 'yaw', fallback: 0),
      );
    }
    if (value is Map) {
      final json = Map<String, Object?>.from(value);
      return NeutralPosition(
        pitch: _readDouble(json, 'pitch', fallback: 0),
        roll: _readDouble(json, 'roll', fallback: 0),
        yaw: _readDouble(json, 'yaw', fallback: 0),
      );
    }
    return const NeutralPosition(pitch: 0, roll: 0, yaw: 0);
  }

  FeedbackResult _readFeedbackResult(Object? value) {
    if (value is String) {
      for (final result in FeedbackResult.values) {
        if (result.name == value) {
          return result;
        }
      }
    }
    return FeedbackResult.miss;
  }

  HapticPattern _readHapticPattern(Object? value) {
    if (value is String) {
      for (final pattern in HapticPattern.values) {
        if (pattern.name == value) {
          return pattern;
        }
      }
    }
    return HapticPattern.light;
  }

  GameId _readGameId(Object? value) {
    return _readOptionalGameId(value) ?? GameId.motionSaber;
  }

  GameId? _readOptionalGameId(Object? value) {
    if (value is String) {
      for (final gameId in GameId.values) {
        if (gameId.name == value) {
          return gameId;
        }
      }
    }
    return null;
  }

  List<GameId> _readGameIds(Object? value) {
    final values = value is List ? value : const [];
    final result = <GameId>[];
    for (final item in values) {
      final gameId = _readOptionalGameId(item);
      if (gameId != null) {
        result.add(gameId);
      }
    }
    return result.isEmpty ? const [GameId.motionSaber] : result;
  }

  GameCommand _readGameCommand(Object? value) {
    if (value is String) {
      for (final command in GameCommand.values) {
        if (command.name == value) {
          return command;
        }
      }
    }
    return GameCommand.startGame;
  }

  RoomPhase _readRoomPhase(Object? value) {
    if (value is String) {
      for (final phase in RoomPhase.values) {
        if (phase.name == value) {
          return phase;
        }
      }
    }
    return RoomPhase.lobby;
  }

  List<PlayerScoreSnapshot> _readPlayerScores(Object? value) {
    final values = value is List ? value : const [];
    return [
      for (final item in values)
        if (item is Map<String, Object?>)
          _readPlayerScore(item)
        else if (item is Map)
          _readPlayerScore(Map<String, Object?>.from(item)),
    ];
  }

  PlayerScoreSnapshot _readPlayerScore(Map<String, Object?> json) {
    return PlayerScoreSnapshot(
      playerId: _readString(json, 'playerId', fallback: 'unknown-player'),
      name: _readString(json, 'name', fallback: 'Player'),
      score: _readInt(json, 'score', fallback: 0),
      combo: _readInt(json, 'combo', fallback: 0),
      maxCombo: _readInt(json, 'maxCombo', fallback: 0),
      hits: _readInt(json, 'hits', fallback: 0),
      misses: _readInt(json, 'misses', fallback: 0),
      rank: _readInt(json, 'rank', fallback: 0),
      connected: _readBool(json, 'connected', fallback: true),
    );
  }
}
