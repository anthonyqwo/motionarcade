import 'dart:async';
import 'dart:io';

import '../shared/models/motion_event.dart';
import 'connection_status.dart';
import 'motion_event_codec.dart';

class WebSocketClientService {
  WebSocketClientService({MotionEventCodec codec = const MotionEventCodec()})
    : _codec = codec;

  final MotionEventCodec _codec;
  final StreamController<ConnectionStatus> _statusController =
      StreamController<ConnectionStatus>.broadcast();
  final StreamController<MotionEvent> _eventsController =
      StreamController<MotionEvent>.broadcast();

  WebSocket? _socket;
  ConnectionStatus _status = ConnectionStatus.idle;

  Stream<ConnectionStatus> get statusChanges => _statusController.stream;
  ConnectionStatus get status => _status;
  Stream<MotionEvent> get events => _eventsController.stream;

  Future<void> connect(Uri uri) async {
    await disconnect();
    _setStatus(ConnectionStatus.connecting);

    try {
      final socket = await WebSocket.connect(uri.toString()).timeout(
        const Duration(seconds: 5),
      );
      socket.pingInterval = const Duration(seconds: 5);
      _socket = socket;
      _setStatus(ConnectionStatus.connected);
      socket.listen(
        (message) {
          if (message is String) {
            try {
              final event = _codec.decode(message);
              _eventsController.add(event);
            } catch (_) {
              // Ignore bad messages
            }
          }
        },
        onDone: () {
          _socket = null;
          _setStatus(ConnectionStatus.disconnected);
        },
        onError: (_) {
          _socket = null;
          _setStatus(ConnectionStatus.error);
        },
      );
    } catch (_) {
      _socket = null;
      _setStatus(ConnectionStatus.error);
      rethrow;
    }
  }

  void send(MotionEvent event) {
    final socket = _socket;
    if (socket == null || _status != ConnectionStatus.connected) {
      throw StateError('WebSocket client is not connected.');
    }
    socket.add(_codec.encode(event));
  }

  Future<void> disconnect() async {
    final socket = _socket;
    _socket = null;
    if (socket != null) {
      await socket.close();
      _setStatus(ConnectionStatus.disconnected);
    }
  }

  void _setStatus(ConnectionStatus status) {
    _status = status;
    _statusController.add(status);
  }
}
