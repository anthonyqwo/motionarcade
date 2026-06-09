import 'dart:math' as math;

class SensorSample {
  const SensorSample({
    required this.x,
    required this.y,
    required this.z,
    required this.timestamp,
  });

  final double x;
  final double y;
  final double z;
  final DateTime timestamp;

  double get magnitude => math.sqrt(x * x + y * y + z * z);
}

class MotionSensorSnapshot {
  const MotionSensorSnapshot({
    this.accelerometer,
    this.gyroscope,
    this.isActive = false,
    this.errorMessage,
  });

  final SensorSample? accelerometer;
  final SensorSample? gyroscope;
  final bool isActive;
  final String? errorMessage;

  double get motionMagnitude {
    final accel = accelerometer?.magnitude ?? 0;
    final gyro = gyroscope?.magnitude ?? 0;
    return accel * 0.3 + gyro * 0.7;
  }

  MotionSensorSnapshot copyWith({
    SensorSample? accelerometer,
    SensorSample? gyroscope,
    bool? isActive,
    String? errorMessage,
    bool clearError = false,
  }) {
    return MotionSensorSnapshot(
      accelerometer: accelerometer ?? this.accelerometer,
      gyroscope: gyroscope ?? this.gyroscope,
      isActive: isActive ?? this.isActive,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }
}
