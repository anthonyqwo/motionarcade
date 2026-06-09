import 'dart:math' as math;

class Vector3Sample {
  const Vector3Sample({required this.x, required this.y, required this.z});

  final double x;
  final double y;
  final double z;

  double get magnitude => math.sqrt(x * x + y * y + z * z);

  Vector3Sample get normalized {
    final length = magnitude;
    if (length == 0) {
      return const Vector3Sample(x: 0, y: 0, z: 0);
    }

    return Vector3Sample(x: x / length, y: y / length, z: z / length);
  }

  Vector3Sample get inverse => Vector3Sample(x: -x, y: -y, z: -z);

  Vector3Sample operator +(Vector3Sample other) {
    return Vector3Sample(x: x + other.x, y: y + other.y, z: z + other.z);
  }

  Vector3Sample operator -(Vector3Sample other) {
    return Vector3Sample(x: x - other.x, y: y - other.y, z: z - other.z);
  }

  Vector3Sample operator *(double scale) {
    return Vector3Sample(x: x * scale, y: y * scale, z: z * scale);
  }

  double dot(Vector3Sample other) {
    return x * other.x + y * other.y + z * other.z;
  }

  Vector3Sample cross(Vector3Sample other) {
    return Vector3Sample(
      x: y * other.z - z * other.y,
      y: z * other.x - x * other.z,
      z: x * other.y - y * other.x,
    );
  }
}

class ControllerGripFrame {
  const ControllerGripFrame({
    required this.rightAxis,
    required this.upAxis,
    required this.forwardAxis,
    required this.name,
  });

  static const flatTest = ControllerGripFrame(
    rightAxis: Vector3Sample(x: 1, y: 0, z: 0),
    upAxis: Vector3Sample(x: 0, y: 1, z: 0),
    forwardAxis: Vector3Sample(x: 0, y: 0, z: 1),
    name: 'flat_test',
  );

  final Vector3Sample rightAxis;
  final Vector3Sample upAxis;
  final Vector3Sample forwardAxis;
  final String name;

  factory ControllerGripFrame.knifeSideDown(Vector3Sample gravity) {
    final downAxis = gravity.normalized;
    if (downAxis.magnitude == 0) {
      return flatTest;
    }

    final upAxis = downAxis.inverse;
    const pointingVector = Vector3Sample(x: 0, y: 1, z: 0);
    var forwardAxis =
        (pointingVector - upAxis * pointingVector.dot(upAxis)).normalized;

    if (forwardAxis.magnitude < 0.001) {
      return flatTest;
    }

    final rightAxis = forwardAxis.cross(upAxis).normalized;
    forwardAxis = rightAxis.cross(upAxis).normalized;

    return ControllerGripFrame(
      rightAxis: rightAxis,
      upAxis: upAxis,
      forwardAxis: forwardAxis,
      name: 'knife_side_down',
    );
  }

  Vector3Sample transform(Vector3Sample vector) {
    return Vector3Sample(
      x: vector.dot(rightAxis),
      y: vector.dot(upAxis),
      z: vector.dot(forwardAxis),
    );
  }
}

class QuaternionSample {
  const QuaternionSample({
    required this.x,
    required this.y,
    required this.z,
    required this.w,
  });

  static const identity = QuaternionSample(x: 0, y: 0, z: 0, w: 1);

  final double x;
  final double y;
  final double z;
  final double w;

  double get norm => math.sqrt(x * x + y * y + z * z + w * w);

  QuaternionSample get normalized {
    final length = norm;
    if (length == 0) {
      return identity;
    }

    return QuaternionSample(
      x: x / length,
      y: y / length,
      z: z / length,
      w: w / length,
    );
  }

  QuaternionSample get inverse {
    final lengthSquared = x * x + y * y + z * z + w * w;
    if (lengthSquared == 0) {
      return identity;
    }

    return QuaternionSample(
      x: -x / lengthSquared,
      y: -y / lengthSquared,
      z: -z / lengthSquared,
      w: w / lengthSquared,
    );
  }

  QuaternionSample operator *(QuaternionSample other) {
    return QuaternionSample(
      w: w * other.w - x * other.x - y * other.y - z * other.z,
      x: w * other.x + x * other.w + y * other.z - z * other.y,
      y: w * other.y - x * other.z + y * other.w + z * other.x,
      z: w * other.z + x * other.y - y * other.x + z * other.w,
    );
  }

  Vector3Sample rotate(Vector3Sample vector) {
    final q = normalized;
    final v = QuaternionSample(x: vector.x, y: vector.y, z: vector.z, w: 0);
    final rotated = q * v * q.inverse;
    return Vector3Sample(x: rotated.x, y: rotated.y, z: rotated.z);
  }
}

class FusedMotionSample {
  const FusedMotionSample({
    required this.attitude,
    required this.gravity,
    required this.userAcceleration,
    required this.rotationRate,
    required this.timestamp,
    required this.source,
    this.isAvailable = true,
  });

  final QuaternionSample attitude;
  final Vector3Sample gravity;
  final Vector3Sample userAcceleration;
  final Vector3Sample rotationRate;
  final DateTime timestamp;
  final String source;
  final bool isAvailable;

  double get motionMagnitude {
    return userAcceleration.magnitude * 0.6 + rotationRate.magnitude * 0.4;
  }

  FusedMotionSample toControllerFrame(QuaternionSample initialAttitude) {
    final relativeRotation = initialAttitude.inverse * attitude;
    return FusedMotionSample(
      attitude: relativeRotation.normalized,
      gravity: relativeRotation.rotate(gravity),
      userAcceleration: relativeRotation.rotate(userAcceleration),
      rotationRate: relativeRotation.rotate(rotationRate),
      timestamp: timestamp,
      source: source,
      isAvailable: isAvailable,
    );
  }

  FusedMotionSample toGripFrame(ControllerGripFrame gripFrame) {
    return FusedMotionSample(
      attitude: attitude,
      gravity: gripFrame.transform(gravity),
      userAcceleration: gripFrame.transform(userAcceleration),
      rotationRate: gripFrame.transform(rotationRate),
      timestamp: timestamp,
      source: '$source:${gripFrame.name}',
      isAvailable: isAvailable,
    );
  }

  static FusedMotionSample fromMap(Map<dynamic, dynamic> map) {
    final timestampMillis = _doubleValue(map['timestampMillis']);
    return FusedMotionSample(
      attitude: QuaternionSample(
        x: _doubleValue(map['attitudeX']),
        y: _doubleValue(map['attitudeY']),
        z: _doubleValue(map['attitudeZ']),
        w: _doubleValue(map['attitudeW'], fallback: 1),
      ).normalized,
      gravity: Vector3Sample(
        x: _doubleValue(map['gravityX']),
        y: _doubleValue(map['gravityY']),
        z: _doubleValue(map['gravityZ']),
      ),
      userAcceleration: Vector3Sample(
        x: _doubleValue(map['userAccelerationX']),
        y: _doubleValue(map['userAccelerationY']),
        z: _doubleValue(map['userAccelerationZ']),
      ),
      rotationRate: Vector3Sample(
        x: _doubleValue(map['rotationRateX']),
        y: _doubleValue(map['rotationRateY']),
        z: _doubleValue(map['rotationRateZ']),
      ),
      timestamp: DateTime.fromMillisecondsSinceEpoch(timestampMillis.round()),
      source: map['source']?.toString() ?? 'native',
      isAvailable: map['isAvailable'] != false,
    );
  }

  static double _doubleValue(Object? value, {double fallback = 0}) {
    if (value is num) {
      return value.toDouble();
    }
    return fallback;
  }
}

class FusedMotionSnapshot {
  const FusedMotionSnapshot({
    this.sample,
    this.controllerSample,
    this.isActive = false,
    this.errorMessage,
  });

  final FusedMotionSample? sample;
  final FusedMotionSample? controllerSample;
  final bool isActive;
  final String? errorMessage;

  bool get hasUsableSample => isActive && controllerSample != null;

  FusedMotionSnapshot copyWith({
    FusedMotionSample? sample,
    FusedMotionSample? controllerSample,
    bool? isActive,
    String? errorMessage,
    bool clearError = false,
  }) {
    return FusedMotionSnapshot(
      sample: sample ?? this.sample,
      controllerSample: controllerSample ?? this.controllerSample,
      isActive: isActive ?? this.isActive,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }
}
