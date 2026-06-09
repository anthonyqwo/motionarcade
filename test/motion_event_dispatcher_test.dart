import 'package:flutter_test/flutter_test.dart';
import 'package:motionarcade/network/motion_event_dispatcher.dart';
import 'package:motionarcade/shared/models/motion_event.dart';

void main() {
  test('dispatches event to matching handler', () {
    final calls = <String>[];
    final dispatcher = MotionEventDispatcher(
      onJoin: (_) => calls.add('join'),
      onDisconnect: (_) => calls.add('disconnect'),
      onSlash: (_) => calls.add('slash'),
      onShootHold: (_) => calls.add('shootHold'),
      onMotionTrail: (_) => calls.add('motionTrail'),
      onUnknown: (_) => calls.add('unknown'),
    );

    dispatcher.dispatch(
      JoinEvent(
        playerId: 'p1',
        timestamp: DateTime.fromMillisecondsSinceEpoch(1000),
        name: 'Player',
        device: 'test',
      ),
    );
    dispatcher.dispatch(
      DisconnectEvent(
        playerId: 'p1',
        timestamp: DateTime.fromMillisecondsSinceEpoch(1000),
      ),
    );
    dispatcher.dispatch(
      SlashEvent(
        playerId: 'p1',
        timestamp: DateTime.fromMillisecondsSinceEpoch(1000),
        direction: MotionDirection.down,
        power: 0.5,
        durationMs: 100,
      ),
    );
    dispatcher.dispatch(
      ShootHoldEvent(
        playerId: 'p1',
        timestamp: DateTime.fromMillisecondsSinceEpoch(1000),
      ),
    );
    dispatcher.dispatch(
      MotionTrailEvent(
        playerId: 'p1',
        timestamp: DateTime.fromMillisecondsSinceEpoch(1000),
        referenceTimestamp: DateTime.fromMillisecondsSinceEpoch(1000),
        samples: const [],
      ),
    );
    dispatcher.dispatch(
      UnknownMotionEvent(
        type: 'mystery',
        playerId: 'p1',
        timestamp: DateTime.fromMillisecondsSinceEpoch(1000),
        payload: const {'type': 'mystery'},
      ),
    );

    expect(calls, [
      'join',
      'disconnect',
      'slash',
      'shootHold',
      'motionTrail',
      'unknown',
    ]);
  });
}
