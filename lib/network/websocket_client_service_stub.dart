import 'dart:async';

import '../shared/models/motion_event.dart';
import 'connection_status.dart';

class WebSocketClientService {
  final StreamController<ConnectionStatus> _statusController =
      StreamController<ConnectionStatus>.broadcast();
  final StreamController<MotionEvent> _eventsController =
      StreamController<MotionEvent>.broadcast();

  Stream<ConnectionStatus> get statusChanges => _statusController.stream;
  ConnectionStatus get status => ConnectionStatus.unsupported;
  Stream<MotionEvent> get events => _eventsController.stream;

  Future<void> connect(Uri uri) {
    _statusController.add(ConnectionStatus.unsupported);
    throw UnsupportedError(
      'WebSocket client is not supported on this platform.',
    );
  }

  void send(MotionEvent event) {
    throw UnsupportedError(
      'WebSocket client is not supported on this platform.',
    );
  }

  Future<void> disconnect() async {
    await _statusController.close();
    await _eventsController.close();
  }
}
