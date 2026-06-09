import 'package:flutter_test/flutter_test.dart';
import 'package:motionarcade/network/websocket_client_service.dart';
import 'package:motionarcade/network/websocket_server_service.dart';
import 'package:motionarcade/shared/models/motion_event.dart';

void main() {
  test('client sends join event to local server', () async {
    final server = WebSocketServerService();
    final client = WebSocketClientService();

    final host = await server.start(port: 0);
    addTearDown(client.disconnect);
    addTearDown(server.stop);

    await client.connect(Uri.parse('ws://127.0.0.1:${host.port}'));

    final received = server.events.first;
    client.send(
      JoinEvent(
        playerId: 'p1',
        timestamp: DateTime.fromMillisecondsSinceEpoch(1000),
        name: 'Player 1',
        device: 'test-device',
      ),
    );

    final event = await received.timeout(const Duration(seconds: 2));

    expect(event, isA<JoinEvent>());
    final join = event as JoinEvent;
    expect(join.playerId, 'p1');
    expect(join.name, 'Player 1');
  });

  test('server detects client disconnect and emits DisconnectEvent', () async {
    final server = WebSocketServerService();
    final client = WebSocketClientService();

    final host = await server.start(port: 0);
    addTearDown(client.disconnect);
    addTearDown(server.stop);

    await client.connect(Uri.parse('ws://127.0.0.1:${host.port}'));

    final receivedEvents = <MotionEvent>[];
    final sub = server.events.listen(receivedEvents.add);
    addTearDown(sub.cancel);

    // Join
    client.send(
      JoinEvent(
        playerId: 'p2',
        timestamp: DateTime.fromMillisecondsSinceEpoch(1000),
        name: 'Player 2',
        device: 'test-device',
      ),
    );

    // Wait for join event to be processed
    await Future<void>.delayed(const Duration(milliseconds: 100));

    // Disconnect client
    await client.disconnect();

    // Wait for server to process disconnect
    await Future<void>.delayed(const Duration(milliseconds: 200));

    expect(receivedEvents, hasLength(2));
    expect(receivedEvents[0], isA<JoinEvent>());
    expect(receivedEvents[1], isA<DisconnectEvent>());
    expect(receivedEvents[1].playerId, 'p2');
  });

  test('server sends feedback event and client receives it', () async {
    final server = WebSocketServerService();
    final client = WebSocketClientService();

    final host = await server.start(port: 0);
    addTearDown(client.disconnect);
    addTearDown(server.stop);

    await client.connect(Uri.parse('ws://127.0.0.1:${host.port}'));

    // Send Join first so the server associates player ID with the socket
    client.send(
      JoinEvent(
        playerId: 'p3',
        timestamp: DateTime.fromMillisecondsSinceEpoch(1000),
        name: 'Player 3',
        device: 'test-device',
      ),
    );

    // Wait for server to process join
    await Future<void>.delayed(const Duration(milliseconds: 100));

    final receivedFuture = client.events.first;

    server.sendToPlayer(
      'p3',
      FeedbackEvent(
        playerId: 'p3',
        timestamp: DateTime.fromMillisecondsSinceEpoch(2000),
        result: FeedbackResult.perfect,
        haptic: HapticPattern.strong,
        durationMs: 80,
        message: 'Perfect!',
      ),
    );

    final event = await receivedFuture.timeout(const Duration(seconds: 2));

    expect(event, isA<FeedbackEvent>());
    final feedback = event as FeedbackEvent;
    expect(feedback.playerId, 'p3');
    expect(feedback.result, FeedbackResult.perfect);
    expect(feedback.haptic, HapticPattern.strong);
    expect(feedback.message, 'Perfect!');
  });
}
