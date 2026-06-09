import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../shared/models/motion_event.dart';
import 'udp_motion_packet_codec.dart';

class UdpMotionServerService {
  UdpMotionServerService({
    required this.roomToken,
    UdpMotionPacketCodec codec = const UdpMotionPacketCodec(),
  }) : _codec = codec;

  final String roomToken;
  final UdpMotionPacketCodec _codec;
  final StreamController<MotionEvent> _eventsController =
      StreamController<MotionEvent>.broadcast();
  final Map<String, int> _latestSequenceByPlayer = {};

  RawDatagramSocket? _socket;

  Stream<MotionEvent> get events => _eventsController.stream;
  int? get port => _socket?.port;
  bool get isRunning => _socket != null;

  Future<int> start({int port = 0}) async {
    final existing = _socket;
    if (existing != null) {
      return existing.port;
    }

    final socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, port);
    _socket = socket;
    socket.listen((event) {
      if (event == RawSocketEvent.read) {
        _readDatagrams(socket);
      }
    });
    return socket.port;
  }

  Future<void> stop() async {
    _socket?.close();
    _socket = null;
    _latestSequenceByPlayer.clear();
  }

  void _readDatagrams(RawDatagramSocket socket) {
    while (true) {
      final datagram = socket.receive();
      if (datagram == null) {
        return;
      }

      try {
        final packet = _codec.decodeTrail(utf8.decode(datagram.data));
        if (packet.roomToken != roomToken) {
          continue;
        }

        final playerId = packet.event.playerId;
        final latestSequence = _latestSequenceByPlayer[playerId];
        if (latestSequence != null && packet.sequence <= latestSequence) {
          continue;
        }
        _latestSequenceByPlayer[playerId] = packet.sequence;
        _eventsController.add(packet.event.normalized(DateTime.now()));
      } catch (_) {
        // Ignore malformed or stale UDP packets.
      }
    }
  }
}
