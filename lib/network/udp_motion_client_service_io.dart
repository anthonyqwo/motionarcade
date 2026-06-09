import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../shared/models/motion_event.dart';
import 'udp_motion_packet_codec.dart';

class UdpMotionClientService {
  UdpMotionClientService({
    UdpMotionPacketCodec codec = const UdpMotionPacketCodec(),
  }) : _codec = codec;

  final UdpMotionPacketCodec _codec;

  RawDatagramSocket? _socket;
  InternetAddress? _host;
  int? _port;
  String? _roomToken;
  int _sequence = 0;

  bool get isConnected =>
      _socket != null && _host != null && _port != null && _roomToken != null;

  Future<void> connect({
    required String host,
    required int port,
    required String roomToken,
  }) async {
    await disconnect();
    _host = InternetAddress(host);
    _port = port;
    _roomToken = roomToken;
    _sequence = 0;
    _socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
  }

  bool sendTrail(MotionTrailEvent event) {
    final socket = _socket;
    final host = _host;
    final port = _port;
    final roomToken = _roomToken;
    if (socket == null || host == null || port == null || roomToken == null) {
      return false;
    }

    final packet = _codec.encodeTrail(
      event: event,
      roomToken: roomToken,
      sequence: ++_sequence,
    );
    final bytesSent = socket.send(utf8.encode(packet), host, port);
    return bytesSent > 0;
  }

  Future<void> disconnect() async {
    _socket?.close();
    _socket = null;
    _host = null;
    _port = null;
    _roomToken = null;
  }
}
