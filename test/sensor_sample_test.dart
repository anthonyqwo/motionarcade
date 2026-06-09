import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:motionarcade/controller/motion_sensor_service.dart';
import 'package:motionarcade/shared/models/sensor_sample.dart';
import 'package:sensors_plus/sensors_plus.dart';

void main() {
  test('sensor sample calculates vector magnitude', () {
    final sample = SensorSample(
      x: 3,
      y: 4,
      z: 12,
      timestamp: DateTime.fromMillisecondsSinceEpoch(1000),
    );

    expect(sample.magnitude, 13);
  });

  test('sensor snapshot combines accelerometer and gyroscope magnitude', () {
    final snapshot = MotionSensorSnapshot(
      accelerometer: SensorSample(
        x: 3,
        y: 4,
        z: 0,
        timestamp: DateTime.fromMillisecondsSinceEpoch(1000),
      ),
      gyroscope: SensorSample(
        x: 0,
        y: 0,
        z: 10,
        timestamp: DateTime.fromMillisecondsSinceEpoch(1000),
      ),
    );

    expect(snapshot.motionMagnitude, closeTo(8.5, 0.001));
  });

  test('motion sensor service publishes injected sensor events', () async {
    final accelerometer = StreamController<AccelerometerEvent>();
    final gyroscope = StreamController<GyroscopeEvent>();
    final service = MotionSensorService(
      accelerometerEvents: accelerometer.stream,
      gyroscopeEvents: gyroscope.stream,
    );
    addTearDown(accelerometer.close);
    addTearDown(gyroscope.close);
    addTearDown(service.dispose);

    service.start();

    final snapshots = <MotionSensorSnapshot>[];
    final subscription = service.snapshots.listen(snapshots.add);
    addTearDown(subscription.cancel);

    final timestamp = DateTime.fromMillisecondsSinceEpoch(1000);
    accelerometer.add(AccelerometerEvent(1, 2, 3, timestamp));
    gyroscope.add(GyroscopeEvent(4, 5, 6, timestamp));
    await pumpEventQueue();

    expect(service.currentSnapshot.isActive, isTrue);
    expect(service.currentSnapshot.accelerometer?.x, 1);
    expect(service.currentSnapshot.gyroscope?.z, 6);

    await service.stop();

    expect(service.currentSnapshot.isActive, isFalse);
    expect(snapshots, isNotEmpty);
  });
}
