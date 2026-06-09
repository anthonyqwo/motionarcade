import '../../network/websocket_server_service.dart';
import '../models/motion_event.dart';

class FeedbackService {
  FeedbackService(this._server);

  final WebSocketServerService _server;

  void sendFeedback({
    required String playerId,
    required FeedbackResult result,
    required HapticPattern haptic,
    required int durationMs,
    String? message,
  }) {
    final event = FeedbackEvent(
      playerId: playerId,
      timestamp: DateTime.now(),
      result: result,
      haptic: haptic,
      durationMs: durationMs,
      message: message,
    );
    _server.sendToPlayer(playerId, event);
  }
}
