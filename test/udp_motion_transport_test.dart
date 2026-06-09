import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:motionarcade/network/udp_motion_client_service.dart';
import 'package:motionarcade/network/udp_motion_packet_codec.dart';
import 'package:motionarcade/network/udp_motion_server_service.dart';
import 'package:motionarcade/shared/models/motion_event.dart';
import 'package:motionarcade/shared/models/motion_trail_sample.dart';

void main() {
  MotionTrailEvent trailEvent({
    String playerId = 'p1',
    int timestampMs = 1000,
  }) {
    final timestamp = DateTime.fromMillisecondsSinceEpoch(timestampMs);
    return MotionTrailEvent(
      playerId: playerId,
      timestamp: timestamp,
      referenceTimestamp: timestamp,
      samples: const [
        MotionTrailSample(tMs: 0, tipX: 0.1, tipY: 0.2, strength: 1.5),
        MotionTrailSample(tMs: 16, tipX: 0.2, tipY: 0.4, strength: 2.5),
      ],
    );
  }

  test('UDP packet codec round-trips compact trail packets', () {
    const codec = UdpMotionPacketCodec();
    final encoded = codec.encodeTrail(
      event: trailEvent(),
      roomToken: 'room-1',
      sequence: 42,
    );

    final decoded = codec.decodeTrail(encoded);

    expect(decoded.roomToken, 'room-1');
    expect(decoded.sequence, 42);
    expect(decoded.event, isA<MotionTrailEvent>());
    expect(decoded.event.playerId, 'p1');
    expect(decoded.event.samples, hasLength(2));
    expect(decoded.event.samples.first.tipX, 0.1);
    expect(decoded.event.samples.last.strength, 2.5);
  });

  test('UDP client sends trail packets to local server', () async {
    final server = UdpMotionServerService(roomToken: 'room-1');
    final client = UdpMotionClientService();

    final port = await server.start(port: 0);
    addTearDown(client.disconnect);
    addTearDown(server.stop);

    await client.connect(host: '127.0.0.1', port: port, roomToken: 'room-1');

    final received = server.events.first;
    expect(client.sendTrail(trailEvent()), isTrue);

    final event = await received.timeout(const Duration(seconds: 2));

    expect(event, isA<MotionTrailEvent>());
    final trail = event as MotionTrailEvent;
    expect(trail.playerId, 'p1');
    expect(trail.samples, hasLength(2));
  });

  test('UDP server drops packets with the wrong room token', () async {
    final server = UdpMotionServerService(roomToken: 'room-1');
    final client = UdpMotionClientService();

    final port = await server.start(port: 0);
    addTearDown(client.disconnect);
    addTearDown(server.stop);

    await client.connect(
      host: '127.0.0.1',
      port: port,
      roomToken: 'other-room',
    );

    expect(client.sendTrail(trailEvent()), isTrue);

    await expectLater(
      server.events.first.timeout(const Duration(milliseconds: 150)),
      throwsA(isA<TimeoutException>()),
    );
  });
}
