import 'dart:async';

import '../shared/models/motion_event.dart';

class UdpMotionServerService {
  UdpMotionServerService({required this.roomToken});

  final String roomToken;
  final StreamController<MotionEvent> _eventsController =
      StreamController<MotionEvent>.broadcast();

  Stream<MotionEvent> get events => _eventsController.stream;
  int? get port => null;
  bool get isRunning => false;

  Future<int> start({int port = 0}) {
    throw UnsupportedError(
      'UDP motion server is not supported on this platform.',
    );
  }

  Future<void> stop() async {}
}
