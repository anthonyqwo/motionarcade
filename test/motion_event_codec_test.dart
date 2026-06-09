import 'package:flutter_test/flutter_test.dart';
import 'package:motionarcade/network/motion_event_codec.dart';
import 'package:motionarcade/shared/models/motion_event.dart';
import 'package:motionarcade/shared/models/motion_trail_sample.dart';

void main() {
  const codec = MotionEventCodec();

  test('encodes and decodes join event', () {
    final event = JoinEvent(
      playerId: 'p1',
      timestamp: DateTime.fromMillisecondsSinceEpoch(1000),
      name: 'Player 1',
      device: 'android',
    );

    final decoded = codec.decode(codec.encode(event));

    expect(decoded, isA<JoinEvent>());
    final join = decoded as JoinEvent;
    expect(join.playerId, 'p1');
    expect(join.name, 'Player 1');
    expect(join.device, 'android');
  });

  test('encodes and decodes button event', () {
    final event = ButtonEvent(
      playerId: 'p1',
      timestamp: DateTime.fromMillisecondsSinceEpoch(1000),
      button: 'test',
    );

    final decoded = codec.decode(codec.encode(event));

    expect(decoded, isA<ButtonEvent>());
    final button = decoded as ButtonEvent;
    expect(button.button, 'test');
    expect(button.pressed, isTrue);
  });

  test('encodes and decodes slash event', () {
    final event = SlashEvent(
      playerId: 'p1',
      timestamp: DateTime.fromMillisecondsSinceEpoch(1000),
      direction: MotionDirection.right,
      power: 0.82,
      durationMs: 120,
    );

    final decoded = codec.decode(codec.encode(event));

    expect(decoded, isA<SlashEvent>());
    final slash = decoded as SlashEvent;
    expect(slash.direction, MotionDirection.right);
    expect(slash.power, 0.82);
    expect(slash.durationMs, 120);
  });

  test('encodes and decodes calibrate event', () {
    final event = CalibrateEvent(
      playerId: 'p1',
      timestamp: DateTime.fromMillisecondsSinceEpoch(1000),
      neutral: const NeutralPosition(pitch: 0.1, roll: -0.2, yaw: 0.3),
    );

    final decoded = codec.decode(codec.encode(event));

    expect(decoded, isA<CalibrateEvent>());
    final calibrate = decoded as CalibrateEvent;
    expect(calibrate.neutral.pitch, 0.1);
    expect(calibrate.neutral.roll, -0.2);
    expect(calibrate.neutral.yaw, 0.3);
  });

  test('encodes and decodes swing event', () {
    final event = SwingEvent(
      playerId: 'p1',
      timestamp: DateTime.fromMillisecondsSinceEpoch(1000),
      direction: MotionDirection.left,
      power: 0.64,
      durationMs: 98,
    );

    final decoded = codec.decode(codec.encode(event));

    expect(decoded, isA<SwingEvent>());
    final swing = decoded as SwingEvent;
    expect(swing.direction, MotionDirection.left);
    expect(swing.power, 0.64);
    expect(swing.durationMs, 98);
  });

  test('encodes and decodes shoot event', () {
    final event = ShootEvent(
      playerId: 'p1',
      timestamp: DateTime.fromMillisecondsSinceEpoch(1000),
      power: 0.76,
      angle: 42,
      offset: -0.08,
      stability: 0.91,
      holdDurationMs: 680,
    );

    final decoded = codec.decode(codec.encode(event));

    expect(decoded, isA<ShootEvent>());
    final shoot = decoded as ShootEvent;
    expect(shoot.power, 0.76);
    expect(shoot.angle, 42);
    expect(shoot.offset, -0.08);
    expect(shoot.stability, 0.91);
    expect(shoot.holdDurationMs, 680);
  });

  test('encodes and decodes shootHold event', () {
    final event = ShootHoldEvent(
      playerId: 'p1',
      timestamp: DateTime.fromMillisecondsSinceEpoch(1000),
      pressed: true,
    );

    final decoded = codec.decode(codec.encode(event));

    expect(decoded, isA<ShootHoldEvent>());
    final shootHold = decoded as ShootHoldEvent;
    expect(shootHold.pressed, isTrue);
  });

  test('encodes and decodes motionTrail event', () {
    final event = MotionTrailEvent(
      playerId: 'p1',
      timestamp: DateTime.fromMillisecondsSinceEpoch(1000),
      referenceTimestamp: DateTime.fromMillisecondsSinceEpoch(1000),
      samples: const [
        MotionTrailSample(tMs: 0, tipX: 0.12, tipY: 0.24, strength: 0.42),
        MotionTrailSample(tMs: 16, tipX: 0.18, tipY: 0.31, strength: 0.55),
      ],
    );

    final decoded = codec.decode(codec.encode(event));

    expect(decoded, isA<MotionTrailEvent>());
    final trail = decoded as MotionTrailEvent;
    expect(trail.referenceTimestamp.millisecondsSinceEpoch, 1000);
    expect(trail.samples.length, 2);
    expect(trail.samples[0].tMs, 0);
    expect(trail.samples[0].tipX, 0.12);
    expect(trail.samples[1].tipY, 0.31);
    expect(trail.samples[1].strength, 0.55);
  });

  test('encodes and decodes feedback event', () {
    final event = FeedbackEvent(
      playerId: 'p1',
      timestamp: DateTime.fromMillisecondsSinceEpoch(1000),
      result: FeedbackResult.perfect,
      haptic: HapticPattern.strong,
      durationMs: 120,
      message: 'perfect',
    );

    final decoded = codec.decode(codec.encode(event));

    expect(decoded, isA<FeedbackEvent>());
    final feedback = decoded as FeedbackEvent;
    expect(feedback.result, FeedbackResult.perfect);
    expect(feedback.haptic, HapticPattern.strong);
    expect(feedback.durationMs, 120);
    expect(feedback.message, 'perfect');
  });

  test('encodes and decodes transport config event', () {
    final event = TransportConfigEvent(
      playerId: 'p1',
      timestamp: DateTime.fromMillisecondsSinceEpoch(1000),
      udpHost: '192.168.1.12',
      udpPort: 8091,
      roomToken: 'room-abc',
      trailRateHz: 30,
      maxBatchSize: 6,
    );

    final decoded = codec.decode(codec.encode(event));

    expect(decoded, isA<TransportConfigEvent>());
    final config = decoded as TransportConfigEvent;
    expect(config.udpHost, '192.168.1.12');
    expect(config.udpPort, 8091);
    expect(config.roomToken, 'room-abc');
    expect(config.trailRateHz, 30);
    expect(config.maxBatchSize, 6);
  });

  test('encodes and decodes game command event', () {
    final event = GameCommandEvent(
      playerId: 'p1',
      timestamp: DateTime.fromMillisecondsSinceEpoch(1000),
      command: GameCommand.selectGame,
      gameId: GameId.basketball,
      requestId: 'req-1',
    );

    final decoded = codec.decode(codec.encode(event));

    expect(decoded, isA<GameCommandEvent>());
    final command = decoded as GameCommandEvent;
    expect(command.command, GameCommand.selectGame);
    expect(command.gameId, GameId.basketball);
    expect(command.requestId, 'req-1');
  });

  test('encodes and decodes room state event', () {
    final event = RoomStateEvent(
      playerId: 'host',
      timestamp: DateTime.fromMillisecondsSinceEpoch(1000),
      selectedGame: GameId.motionSaber,
      availableGames: const [
        GameId.motionSaber,
        GameId.basketball,
        GameId.pingPong,
      ],
      roomPhase: RoomPhase.playing,
      connectedPlayers: 2,
      canStart: false,
      canRestart: true,
      canBackToRoom: true,
      sharedLives: 2,
      maxSharedLives: 3,
      survivedSeconds: 12.5,
      message: 'Playing',
      playerScores: const [
        PlayerScoreSnapshot(
          playerId: 'p1',
          name: 'Player 1',
          score: 120,
          combo: 2,
          maxCombo: 4,
          hits: 3,
          misses: 1,
          rank: 1,
        ),
      ],
    );

    final decoded = codec.decode(codec.encode(event));

    expect(decoded, isA<RoomStateEvent>());
    final state = decoded as RoomStateEvent;
    expect(state.selectedGame, GameId.motionSaber);
    expect(state.availableGames, contains(GameId.basketball));
    expect(state.roomPhase, RoomPhase.playing);
    expect(state.connectedPlayers, 2);
    expect(state.canRestart, isTrue);
    expect(state.sharedLives, 2);
    expect(state.survivedSeconds, 12.5);
    expect(state.scoreForPlayer('p1')?.score, 120);
  });

  test('encodes and decodes disconnect event', () {
    final event = DisconnectEvent(
      playerId: 'p1',
      timestamp: DateTime.fromMillisecondsSinceEpoch(1000),
    );

    final decoded = codec.decode(codec.encode(event));

    expect(decoded, isA<DisconnectEvent>());
    final disconnect = decoded as DisconnectEvent;
    expect(disconnect.playerId, 'p1');
    expect(disconnect.timestamp.millisecondsSinceEpoch, 1000);
  });

  test('preserves unknown event payload', () {
    final decoded = codec.decode(
      '{"type":"mystery","playerId":"p9","timestamp":1000,"value":42}',
    );

    expect(decoded, isA<UnknownMotionEvent>());
    final unknown = decoded as UnknownMotionEvent;
    expect(unknown.type, 'mystery');
    expect(unknown.payload['value'], 42);
  });
}
