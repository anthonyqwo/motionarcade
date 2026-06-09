import 'package:flutter_test/flutter_test.dart';
import 'package:motionarcade/controller/calibration_service.dart';
import 'package:motionarcade/controller/motion_detector.dart';
import 'package:motionarcade/controller/sensitivity_settings.dart';
import 'package:motionarcade/shared/models/motion_event.dart';
import 'package:motionarcade/shared/models/sensor_sample.dart';

void main() {
  MotionSensorSnapshot snapshot({
    double accelX = 0,
    double accelY = 0,
    double accelZ = 0,
    double gyroX = 0,
    double gyroY = 0,
    double gyroZ = 0,
    bool isActive = true,
  }) {
    final timestamp = DateTime.fromMillisecondsSinceEpoch(1000);
    return MotionSensorSnapshot(
      isActive: isActive,
      accelerometer: SensorSample(
        x: accelX,
        y: accelY,
        z: accelZ,
        timestamp: timestamp,
      ),
      gyroscope: SensorSample(
        x: gyroX,
        y: gyroY,
        z: gyroZ,
        timestamp: timestamp,
      ),
    );
  }

  test('does not detect when inactive or below threshold', () {
    final detector = MotionDetector(
      settings: SensitivitySettings.forLevel(SensitivityLevel.medium),
      now: () => DateTime.fromMillisecondsSinceEpoch(1000),
    );

    expect(detector.detect(snapshot(isActive: false, gyroX: 20)), isNull);
    expect(detector.detect(snapshot(gyroX: 1)), isNull);
  });

  test('detects vertical direction from gyroscope x axis', () {
    final detector = MotionDetector(
      settings: SensitivitySettings.forLevel(SensitivityLevel.medium),
      now: () => DateTime.fromMillisecondsSinceEpoch(1000),
    );

    final result = detector.detect(snapshot(gyroX: 12));

    expect(result, isNotNull);
    expect(result!.direction, MotionDirection.up);
    expect(result.power, inInclusiveRange(0, 1));
  });

  test('detects horizontal direction from gyroscope y axis', () {
    final detector = MotionDetector(
      settings: SensitivitySettings.forLevel(SensitivityLevel.medium),
      now: () => DateTime.fromMillisecondsSinceEpoch(1000),
    );

    final result = detector.detect(snapshot(gyroY: -12));

    expect(result, isNotNull);
    expect(result!.direction, MotionDirection.left);
  });

  test('detects forward direction from accelerometer z axis', () {
    final calibration = CalibrationService();
    calibration.calibrate(snapshot(accelZ: 9.8, gyroX: 0, gyroY: 0, gyroZ: 0));
    final detector = MotionDetector(
      calibrationService: calibration,
      settings: SensitivitySettings.forLevel(SensitivityLevel.medium),
      now: () => DateTime.fromMillisecondsSinceEpoch(1000),
    );

    final result = detector.detect(snapshot(accelZ: -28, gyroX: 0));

    expect(result, isNotNull);
    expect(result!.direction, MotionDirection.forward);
  });

  test('does not use raw z gravity before calibration', () {
    final detector = MotionDetector(
      settings: SensitivitySettings.forLevel(SensitivityLevel.medium),
      now: () => DateTime.fromMillisecondsSinceEpoch(1000),
    );

    final result = detector.detect(snapshot(accelZ: -28, gyroY: -12));

    expect(result, isNotNull);
    expect(result!.direction, MotionDirection.left);
  });

  test('does not classify small z movement as forward or backward', () {
    final detector = MotionDetector(
      settings: SensitivitySettings.forLevel(SensitivityLevel.medium),
      now: () => DateTime.fromMillisecondsSinceEpoch(1000),
    );

    final result = detector.detect(snapshot(accelZ: -12, gyroY: -10));

    expect(result, isNotNull);
    expect(result!.direction, MotionDirection.left);
  });

  test('keeps gyro direction when z is not dominant enough', () {
    final detector = MotionDetector(
      settings: SensitivitySettings.forLevel(SensitivityLevel.medium),
      now: () => DateTime.fromMillisecondsSinceEpoch(1000),
    );

    final result = detector.detect(snapshot(accelZ: -19, gyroX: 12));

    expect(result, isNotNull);
    expect(result!.direction, MotionDirection.up);
  });

  test('detects backward direction from accelerometer z axis', () {
    final calibration = CalibrationService();
    calibration.calibrate(snapshot(accelZ: 9.8, gyroX: 0, gyroY: 0, gyroZ: 0));
    final detector = MotionDetector(
      calibrationService: calibration,
      settings: SensitivitySettings.forLevel(SensitivityLevel.medium),
      now: () => DateTime.fromMillisecondsSinceEpoch(1000),
    );

    final result = detector.detect(snapshot(accelZ: 30));

    expect(result, isNotNull);
    expect(result!.direction, MotionDirection.backward);
  });

  test('cooldown prevents duplicate detections', () {
    var now = DateTime.fromMillisecondsSinceEpoch(1000);
    final detector = MotionDetector(
      settings: SensitivitySettings.forLevel(SensitivityLevel.medium),
      now: () => now,
    );

    final first = detector.detect(snapshot(gyroX: 12));
    final second = detector.detect(snapshot(gyroX: 12));
    now = now.add(const Duration(milliseconds: 301));
    final third = detector.detect(snapshot(gyroX: 12));

    expect(first, isNotNull);
    expect(second, isNull);
    expect(third, isNotNull);
  });

  test('calibration offsets gyroscope neutral position', () {
    final calibration = CalibrationService();
    final detector = MotionDetector(
      calibrationService: calibration,
      settings: SensitivitySettings.forLevel(SensitivityLevel.high),
      now: () => DateTime.fromMillisecondsSinceEpoch(1000),
    );

    final neutral = calibration.calibrate(
      snapshot(accelZ: 9.8, gyroX: 4, gyroY: 0, gyroZ: 0),
    );
    final result = detector.detect(
      snapshot(accelZ: 9.8, gyroX: 4.2, gyroY: 0, gyroZ: 0),
    );

    expect(neutral, isNotNull);
    expect(result, isNull);
  });

  test('detection result converts to slash event', () {
    final result = MotionDetectionResult(
      direction: MotionDirection.down,
      power: 0.5,
      magnitude: 12,
      durationMs: 300,
      detectedAt: DateTime.fromMillisecondsSinceEpoch(1000),
    );

    final event = result.toSlashEvent(playerId: 'p1');

    expect(event.playerId, 'p1');
    expect(event.direction, MotionDirection.down);
    expect(event.power, 0.5);
  });
}
