import 'dart:async';

import 'package:sensors_plus/sensors_plus.dart';

import '../shared/models/sensor_sample.dart';

class MotionSensorService {
  MotionSensorService({
    Stream<AccelerometerEvent>? accelerometerEvents,
    Stream<GyroscopeEvent>? gyroscopeEvents,
  }) : _accelerometerEvents = accelerometerEvents ?? accelerometerEventStream(),
       _gyroscopeEvents = gyroscopeEvents ?? gyroscopeEventStream();

  final Stream<AccelerometerEvent> _accelerometerEvents;
  final Stream<GyroscopeEvent> _gyroscopeEvents;
  final StreamController<MotionSensorSnapshot> _snapshotController =
      StreamController<MotionSensorSnapshot>.broadcast();

  StreamSubscription<AccelerometerEvent>? _accelerometerSubscription;
  StreamSubscription<GyroscopeEvent>? _gyroscopeSubscription;
  MotionSensorSnapshot _snapshot = const MotionSensorSnapshot();

  Stream<MotionSensorSnapshot> get snapshots => _snapshotController.stream;
  MotionSensorSnapshot get currentSnapshot => _snapshot;
  bool get isActive => _snapshot.isActive;

  void start() {
    if (isActive) {
      return;
    }

    _setSnapshot(_snapshot.copyWith(isActive: true, clearError: true));

    _accelerometerSubscription = _accelerometerEvents.listen(
      (event) {
        _setSnapshot(
          _snapshot.copyWith(
            accelerometer: SensorSample(
              x: event.x,
              y: event.y,
              z: event.z,
              timestamp: event.timestamp,
            ),
            clearError: true,
          ),
        );
      },
      onError: (Object error) {
        _setSnapshot(
          _snapshot.copyWith(
            isActive: false,
            errorMessage: 'Accelerometer error: $error',
          ),
        );
      },
    );

    _gyroscopeSubscription = _gyroscopeEvents.listen(
      (event) {
        _setSnapshot(
          _snapshot.copyWith(
            gyroscope: SensorSample(
              x: event.x,
              y: event.y,
              z: event.z,
              timestamp: event.timestamp,
            ),
            clearError: true,
          ),
        );
      },
      onError: (Object error) {
        _setSnapshot(
          _snapshot.copyWith(
            isActive: false,
            errorMessage: 'Gyroscope error: $error',
          ),
        );
      },
    );
  }

  Future<void> stop() async {
    await _accelerometerSubscription?.cancel();
    await _gyroscopeSubscription?.cancel();
    _accelerometerSubscription = null;
    _gyroscopeSubscription = null;
    _setSnapshot(_snapshot.copyWith(isActive: false));
  }

  Future<void> dispose() async {
    await stop();
    await _snapshotController.close();
  }

  void _setSnapshot(MotionSensorSnapshot snapshot) {
    _snapshot = snapshot;
    _snapshotController.add(snapshot);
  }
}
