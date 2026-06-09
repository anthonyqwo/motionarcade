import '../shared/models/motion_event.dart';

class UdpMotionClientService {
  bool get isConnected => false;

  Future<void> connect({
    required String host,
    required int port,
    required String roomToken,
  }) async {
    throw UnsupportedError(
      'UDP motion client is not supported on this platform.',
    );
  }

  bool sendTrail(MotionTrailEvent event) => false;

  Future<void> disconnect() async {}
}
