import 'dart:async';
import 'dart:io';

import '../shared/models/motion_event.dart';
import 'connection_status.dart';
import 'motion_event_codec.dart';
import 'room_host_info.dart';

class WebSocketServerService {
  WebSocketServerService({MotionEventCodec codec = const MotionEventCodec()})
    : _codec = codec;

  final MotionEventCodec _codec;
  final StreamController<MotionEvent> _eventsController =
      StreamController<MotionEvent>.broadcast();
  final StreamController<ConnectionStatus> _statusController =
      StreamController<ConnectionStatus>.broadcast();
  final List<WebSocket> _clients = [];
  final Map<WebSocket, String> _socketToPlayerId = {};

  HttpServer? _server;
  ConnectionStatus _status = ConnectionStatus.idle;

  Stream<MotionEvent> get events => _eventsController.stream;
  Stream<ConnectionStatus> get statusChanges => _statusController.stream;
  ConnectionStatus get status => _status;

  Future<RoomHostInfo> start({int port = 8080}) async {
    if (_server != null) {
      final address = await _localIPv4Address();
      return RoomHostInfo(ipAddress: address, port: _server!.port);
    }

    _setStatus(ConnectionStatus.starting);

    try {
      _server = await HttpServer.bind(InternetAddress.anyIPv4, port);
      _setStatus(ConnectionStatus.connected);
      _server!.listen(
        _handleRequest,
        onError: (_) => _setStatus(ConnectionStatus.error),
      );

      return RoomHostInfo(
        ipAddress: await _localIPv4Address(),
        port: _server!.port,
      );
    } catch (_) {
      _setStatus(ConnectionStatus.error);
      rethrow;
    }
  }

  Future<void> stop() async {
    for (final client in List<WebSocket>.from(_clients)) {
      await client.close();
    }
    _clients.clear();
    _socketToPlayerId.clear();
    await _server?.close(force: true);
    _server = null;
    _setStatus(ConnectionStatus.disconnected);
  }

  void _handleRequest(HttpRequest request) {
    if (!WebSocketTransformer.isUpgradeRequest(request)) {
      request.response.statusCode = HttpStatus.notFound;
      unawaited(request.response.close());
      return;
    }

    WebSocketTransformer.upgrade(request).then((socket) {
      socket.pingInterval = const Duration(seconds: 5);
      _clients.add(socket);
      socket.listen(
        (message) {
          if (message is String) {
            try {
              final decoded = _codec.decode(message);
              final event = decoded.normalized(DateTime.now());
              if (event is JoinEvent) {
                _socketToPlayerId[socket] = event.playerId;
              }
              _eventsController.add(event);
            } catch (_) {
              // Ignore decoding/handling errors
            }
          }
        },
        onDone: () => _handleDisconnect(socket),
        onError: (_) => _handleDisconnect(socket),
      );
    });
  }

  void _handleDisconnect(WebSocket socket) {
    final playerId = _socketToPlayerId.remove(socket);
    _clients.remove(socket);
    if (playerId != null) {
      _eventsController.add(
        DisconnectEvent(
          playerId: playerId,
          timestamp: DateTime.now(),
        ),
      );
    }
  }

  void sendToPlayer(String playerId, MotionEvent event) {
    final encoded = _codec.encode(event);
    for (final entry in _socketToPlayerId.entries) {
      if (entry.value == playerId) {
        try {
          entry.key.add(encoded);
        } catch (_) {
          // Handle socket closed during write
        }
        return;
      }
    }
  }

  void broadcast(MotionEvent event) {
    final encoded = _codec.encode(event);
    for (final client in _clients) {
      try {
        client.add(encoded);
      } catch (_) {
        // Handle socket closed during write
      }
    }
  }

  Future<String> _localIPv4Address() async {
    final interfaces = await NetworkInterface.list(
      includeLoopback: false,
      type: InternetAddressType.IPv4,
    );

    // Prioritize physical ethernet/wifi interfaces on macOS/iOS (enX)
    // and standard local interfaces (wlanX, ethX).
    final physicalInterfaces = interfaces.where((interface) {
      final name = interface.name.toLowerCase();
      return name.startsWith('en') ||
          name.startsWith('wlan') ||
          name.startsWith('eth');
    });

    for (final interface in physicalInterfaces) {
      for (final address in interface.addresses) {
        if (!address.isLoopback) {
          return address.address;
        }
      }
    }

    // Fallback to any non-loopback interface
    for (final interface in interfaces) {
      for (final address in interface.addresses) {
        if (!address.isLoopback) {
          return address.address;
        }
      }
    }

    return InternetAddress.loopbackIPv4.address;
  }

  void _setStatus(ConnectionStatus status) {
    _status = status;
    _statusController.add(status);
  }
}
