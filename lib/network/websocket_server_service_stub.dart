import 'dart:async';

import '../shared/models/motion_event.dart';
import 'connection_status.dart';
import 'room_host_info.dart';

class WebSocketServerService {
  final StreamController<MotionEvent> _eventsController =
      StreamController<MotionEvent>.broadcast();
  final StreamController<ConnectionStatus> _statusController =
      StreamController<ConnectionStatus>.broadcast();

  Stream<MotionEvent> get events => _eventsController.stream;
  Stream<ConnectionStatus> get statusChanges => _statusController.stream;
  ConnectionStatus get status => ConnectionStatus.unsupported;

  void sendToPlayer(String playerId, MotionEvent event) {}
  void broadcast(MotionEvent event) {}

  Future<RoomHostInfo> start({int port = 8080}) {
    _statusController.add(ConnectionStatus.unsupported);
    throw UnsupportedError(
      'WebSocket server is not supported on this platform.',
    );
  }

  Future<void> stop() async {
    await _eventsController.close();
    await _statusController.close();
  }
}
