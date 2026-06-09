import 'dart:async';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:motionarcade/controller/calibration_service.dart';
import 'package:motionarcade/controller/fused_motion_service.dart';
import 'package:motionarcade/controller/motion_detector.dart';
import 'package:motionarcade/controller/sensitivity_settings.dart';
import 'package:motionarcade/shared/models/fused_motion_sample.dart';
import 'package:motionarcade/shared/models/motion_event.dart';
import 'package:sensors_plus/sensors_plus.dart';

void main() {
  FusedMotionSample sample({
    QuaternionSample attitude = QuaternionSample.identity,
    double accelX = 0,
    double accelY = 0,
    double accelZ = 0,
    double rotationX = 0,
    double rotationY = 0,
    double rotationZ = 0,
  }) {
    return FusedMotionSample(
      attitude: attitude,
      gravity: const Vector3Sample(x: 0, y: 0, z: 9.80665),
      userAcceleration: Vector3Sample(x: accelX, y: accelY, z: accelZ),
      rotationRate: Vector3Sample(x: rotationX, y: rotationY, z: rotationZ),
      timestamp: DateTime.fromMillisecondsSinceEpoch(1000),
      source: 'test',
    );
  }

  test('quaternion rotates vector into calibrated controller frame', () {
    final halfTurn = math.sqrt(0.5);
    final initial = QuaternionSample.identity;
    final current = QuaternionSample(x: 0, y: 0, z: halfTurn, w: halfTurn);

    final transformed = sample(
      attitude: current,
      accelX: 1,
    ).toControllerFrame(initial);

    expect(transformed.userAcceleration.x, closeTo(0, 0.001));
    expect(transformed.userAcceleration.y, closeTo(1, 0.001));
  });

  test('fused motion service maps native payloads', () async {
    final controller = StreamController<Map<String, Object?>>();
    final service = FusedMotionService(nativeEvents: controller.stream);
    addTearDown(controller.close);
    addTearDown(service.dispose);

    service.start();
    final snapshots = <FusedMotionSnapshot>[];
    final subscription = service.snapshots.listen(snapshots.add);
    addTearDown(subscription.cancel);

    controller.add({
      'attitudeX': 0.0,
      'attitudeY': 0.0,
      'attitudeZ': 0.0,
      'attitudeW': 1.0,
      'gravityX': 0.0,
      'gravityY': 0.0,
      'gravityZ': 9.80665,
      'userAccelerationX': 1.0,
      'userAccelerationY': 2.0,
      'userAccelerationZ': 3.0,
      'rotationRateX': 4.0,
      'rotationRateY': 5.0,
      'rotationRateZ': 6.0,
      'timestampMillis': 1000.0,
      'source': 'unit_test',
    });
    await pumpEventQueue();

    expect(service.currentSnapshot.isActive, isTrue);
    expect(service.currentSnapshot.sample?.source, 'unit_test');
    expect(service.currentSnapshot.controllerSample?.userAcceleration.z, 3);
    expect(snapshots, isNotEmpty);
  });

  test(
    'fused motion service falls back when native bridge is missing',
    () async {
      final native = StreamController<dynamic>();
      final userAcceleration = StreamController<UserAccelerometerEvent>();
      final gyroscope = StreamController<GyroscopeEvent>();
      final service = FusedMotionService(
        nativeEvents: native.stream,
        fallbackUserAccelerometerEvents: userAcceleration.stream,
        fallbackGyroscopeEvents: gyroscope.stream,
      );
      addTearDown(native.close);
      addTearDown(userAcceleration.close);
      addTearDown(gyroscope.close);
      addTearDown(service.dispose);

      service.start();
      native.addError(MissingPluginException('missing'));
      await pumpEventQueue();

      final timestamp = DateTime.fromMillisecondsSinceEpoch(1000);
      gyroscope.add(GyroscopeEvent(1, 2, 3, timestamp));
      userAcceleration.add(UserAccelerometerEvent(4, 5, 6, timestamp));
      await pumpEventQueue();

      expect(service.currentSnapshot.isActive, isTrue);
      expect(service.currentSnapshot.sample?.source, contains('fallback'));
      expect(service.currentSnapshot.controllerSample?.userAcceleration.x, 4);
      expect(service.currentSnapshot.errorMessage, contains('fallback'));
    },
  );

  test('motion detector remaps fused directions for knife grip', () {
    final cases = [
      (sample: sample(accelZ: -24), direction: MotionDirection.backward),
      (sample: sample(accelZ: 24), direction: MotionDirection.forward),
      (sample: sample(accelX: 24), direction: MotionDirection.left),
      (sample: sample(accelX: -24), direction: MotionDirection.right),
      (sample: sample(accelY: 24), direction: MotionDirection.down),
      (sample: sample(accelY: -24), direction: MotionDirection.up),
    ];

    for (final testCase in cases) {
      final detector = MotionDetector(
        settings: SensitivitySettings.forLevel(SensitivityLevel.medium),
        now: () => DateTime.fromMillisecondsSinceEpoch(1000),
      );
      final result = detector.detectFused(
        FusedMotionSnapshot(
          isActive: true,
          sample: testCase.sample,
          controllerSample: testCase.sample,
        ),
      );

      expect(result, isNotNull);
      expect(result!.direction, testCase.direction);
    }
  });

  test('motion detector makes game forward/backward harder to trigger', () {
    final detector = MotionDetector(
      settings: SensitivitySettings.forLevel(SensitivityLevel.medium),
      now: () => DateTime.fromMillisecondsSinceEpoch(1000),
    );

    final result = detector.detectFused(
      FusedMotionSnapshot(
        isActive: true,
        sample: sample(accelZ: -12),
        controllerSample: sample(accelZ: -12),
      ),
    );

    expect(result, isNull);
  });

  test('motion detector makes game left/right easier to trigger', () {
    final detector = MotionDetector(
      settings: SensitivitySettings.forLevel(SensitivityLevel.medium),
      now: () => DateTime.fromMillisecondsSinceEpoch(1000),
    );

    final result = detector.detectFused(
      FusedMotionSnapshot(
        isActive: true,
        sample: sample(accelX: -12),
        controllerSample: sample(accelX: -12),
      ),
    );

    expect(result, isNotNull);
    expect(result!.direction, MotionDirection.right);
  });

  test('calibration stores initial attitude for controller-local motion', () {
    final halfTurn = math.sqrt(0.5);
    final calibration = CalibrationService();
    calibration.calibrateFusedMotion(
      sample(
        attitude: QuaternionSample(x: 0, y: 0, z: halfTurn, w: halfTurn),
      ),
    );

    final adjusted = calibration.applyToFusedMotion(
      sample(
        attitude: QuaternionSample(x: 0, y: 0, z: halfTurn, w: halfTurn),
        accelX: 2,
      ),
    );

    expect(calibration.initialAttitude, isNotNull);
    expect(adjusted.userAcceleration.x, closeTo(-2, 0.001));
    expect(adjusted.userAcceleration.y, closeTo(0, 0.001));
  });

  test('knife grip maps side-down gravity to gameplay up axis', () {
    final calibration = CalibrationService();
    calibration.calibrateFusedMotion(
      FusedMotionSample(
        attitude: QuaternionSample.identity,
        gravity: const Vector3Sample(x: 9.80665, y: 0, z: 0),
        userAcceleration: const Vector3Sample(x: 0, y: 0, z: 0),
        rotationRate: const Vector3Sample(x: 0, y: 0, z: 0),
        timestamp: DateTime.fromMillisecondsSinceEpoch(1000),
        source: 'test',
      ),
    );

    final adjusted = calibration.applyToFusedMotion(
      sample(accelX: -12, accelZ: -3),
    );

    expect(calibration.gripFrame?.name, 'knife_side_down');
    expect(adjusted.userAcceleration.x, closeTo(-3, 0.001));
    expect(adjusted.userAcceleration.y, closeTo(12, 0.001));
    expect(adjusted.userAcceleration.z, closeTo(0, 0.001));
  });

  test('motion detector uses knife grip gameplay axes', () {
    final calibration = CalibrationService();
    calibration.calibrateFusedMotion(
      FusedMotionSample(
        attitude: QuaternionSample.identity,
        gravity: const Vector3Sample(x: 9.80665, y: 0, z: 0),
        userAcceleration: const Vector3Sample(x: 0, y: 0, z: 0),
        rotationRate: const Vector3Sample(x: 0, y: 0, z: 0),
        timestamp: DateTime.fromMillisecondsSinceEpoch(1000),
        source: 'test',
      ),
    );
    final detector = MotionDetector(
      settings: SensitivitySettings.forLevel(SensitivityLevel.medium),
      now: () => DateTime.fromMillisecondsSinceEpoch(1000),
    );
    final adjusted = calibration.applyToFusedMotion(sample(accelX: -24));

    final result = detector.detectFused(
      FusedMotionSnapshot(
        isActive: true,
        sample: adjusted,
        controllerSample: adjusted,
      ),
    );

    expect(result, isNotNull);
    expect(result!.direction, MotionDirection.down);
  });
}
