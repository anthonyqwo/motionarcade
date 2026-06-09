import '../shared/models/motion_event.dart';
import '../shared/models/fused_motion_sample.dart';
import '../shared/models/sensor_sample.dart';
import 'calibration_service.dart';
import 'sensitivity_settings.dart';

class MotionDetector {
  MotionDetector({
    this.settings = const SensitivitySettings(
      level: SensitivityLevel.medium,
      swingThreshold: 7,
      forwardBackwardThreshold: 18,
      maxMagnitude: 24,
      cooldown: Duration(milliseconds: 300),
    ),
    CalibrationService? calibrationService,
    DateTime Function()? now,
  }) : _calibrationService = calibrationService ?? CalibrationService(),
       _now = now ?? DateTime.now;

  final SensitivitySettings settings;
  final CalibrationService _calibrationService;
  final DateTime Function() _now;

  DateTime? _lastTriggerAt;

  MotionDetectionResult? detectFused(FusedMotionSnapshot snapshot) {
    final sample = snapshot.controllerSample;
    if (sample == null || !snapshot.isActive) {
      return null;
    }

    final now = _now();
    if (!_canTrigger(now)) {
      return null;
    }

    final magnitude = sample.motionMagnitude;
    if (magnitude < settings.swingThreshold) {
      return null;
    }

    final candidate = _directionFromFusedMotion(sample);
    final direction = _remapFusedDirection(candidate.direction);
    if (!_passesGameDirectionThreshold(direction, candidate.strength)) {
      return null;
    }

    final power =
        ((magnitude - settings.swingThreshold) /
                (settings.maxMagnitude - settings.swingThreshold))
            .clamp(0.0, 1.0);

    _lastTriggerAt = now;

    return MotionDetectionResult(
      direction: direction,
      power: power,
      magnitude: magnitude,
      durationMs: settings.cooldown.inMilliseconds,
      detectedAt: now,
    );
  }

  MotionDetectionResult? detect(MotionSensorSnapshot snapshot) {
    final gyroscope = snapshot.gyroscope;
    if (gyroscope == null || !snapshot.isActive) {
      return null;
    }

    final now = _now();
    if (!_canTrigger(now)) {
      return null;
    }

    final adjustedGyro = _calibrationService.applyToGyroscope(gyroscope);
    final magnitude = _motionMagnitude(snapshot, adjustedGyro);
    if (magnitude < settings.swingThreshold) {
      return null;
    }

    final adjustedAccel = snapshot.accelerometer == null
        ? null
        : _calibrationService.applyToAccelerometer(snapshot.accelerometer!);
    final direction = _directionFromMotion(
      _calibrationService.isCalibrated ? adjustedAccel : null,
      adjustedGyro,
    );
    final power =
        ((magnitude - settings.swingThreshold) /
                (settings.maxMagnitude - settings.swingThreshold))
            .clamp(0.0, 1.0);

    _lastTriggerAt = now;

    return MotionDetectionResult(
      direction: direction,
      power: power,
      magnitude: magnitude,
      durationMs: settings.cooldown.inMilliseconds,
      detectedAt: now,
    );
  }

  bool _canTrigger(DateTime now) {
    final lastTriggerAt = _lastTriggerAt;
    return lastTriggerAt == null ||
        now.difference(lastTriggerAt) >= settings.cooldown;
  }

  double _motionMagnitude(
    MotionSensorSnapshot snapshot,
    SensorSample adjustedGyro,
  ) {
    final accel = snapshot.accelerometer?.magnitude ?? 0;
    return accel * 0.3 + adjustedGyro.magnitude * 0.7;
  }

  MotionDirection _directionFromMotion(
    SensorSample? accelerometer,
    SensorSample gyroscope,
  ) {
    final x = gyroscope.x.abs();
    final y = gyroscope.y.abs();
    final zAcceleration = accelerometer?.z ?? 0;
    final z = zAcceleration.abs();
    final dominantGyroAxis = x >= y ? x : y;

    final isForwardBackward =
        z >= settings.forwardBackwardThreshold && z > dominantGyroAxis * 1.8;

    if (isForwardBackward) {
      return zAcceleration < 0
          ? MotionDirection.forward
          : MotionDirection.backward;
    }

    if (x >= y) {
      return gyroscope.x >= 0 ? MotionDirection.up : MotionDirection.down;
    }

    return gyroscope.y >= 0 ? MotionDirection.right : MotionDirection.left;
  }

  _FusedDirectionCandidate _directionFromFusedMotion(FusedMotionSample sample) {
    final acceleration = sample.userAcceleration;
    final rotation = sample.rotationRate;
    final forwardBackward = acceleration.z.abs();
    final dominantRotation = rotation.x.abs() >= rotation.y.abs()
        ? rotation.x.abs()
        : rotation.y.abs();

    final leftRightThreshold = settings.swingThreshold * 1.35;
    final isForwardBackward =
        forwardBackward >= leftRightThreshold &&
        forwardBackward > dominantRotation * 1.25;

    if (isForwardBackward) {
      return _FusedDirectionCandidate(
        direction: acceleration.z < 0
            ? MotionDirection.forward
            : MotionDirection.backward,
        strength: forwardBackward,
      );
    }

    final verticalScore = acceleration.y.abs() + rotation.x.abs();
    final horizontalScore = acceleration.x.abs() + rotation.y.abs();

    if (verticalScore >= horizontalScore) {
      final signal = acceleration.y.abs() >= rotation.x.abs()
          ? acceleration.y
          : rotation.x;
      return _FusedDirectionCandidate(
        direction: signal >= 0 ? MotionDirection.up : MotionDirection.down,
        strength: verticalScore,
      );
    }

    final signal = acceleration.x.abs() >= rotation.y.abs()
        ? acceleration.x
        : rotation.y;
    return _FusedDirectionCandidate(
      direction: signal >= 0 ? MotionDirection.right : MotionDirection.left,
      strength: horizontalScore,
    );
  }

  bool _passesGameDirectionThreshold(
    MotionDirection direction,
    double strength,
  ) {
    final threshold = switch (direction) {
      MotionDirection.forward ||
      MotionDirection.backward => settings.forwardBackwardThreshold * 0.85,
      MotionDirection.left ||
      MotionDirection.right => settings.swingThreshold * 1.2,
      MotionDirection.up || MotionDirection.down => settings.swingThreshold,
    };
    return strength >= threshold;
  }

  MotionDirection _remapFusedDirection(MotionDirection direction) {
    return switch (direction) {
      MotionDirection.left => MotionDirection.right,
      MotionDirection.right => MotionDirection.left,
      MotionDirection.up => MotionDirection.down,
      MotionDirection.down => MotionDirection.up,
      MotionDirection.forward => MotionDirection.backward,
      MotionDirection.backward => MotionDirection.forward,
    };
  }
}

class _FusedDirectionCandidate {
  const _FusedDirectionCandidate({
    required this.direction,
    required this.strength,
  });

  final MotionDirection direction;
  final double strength;
}

class MotionDetectionResult {
  const MotionDetectionResult({
    required this.direction,
    required this.power,
    required this.magnitude,
    required this.durationMs,
    required this.detectedAt,
  });

  final MotionDirection direction;
  final double power;
  final double magnitude;
  final int durationMs;
  final DateTime detectedAt;

  SlashEvent toSlashEvent({required String playerId}) {
    return SlashEvent(
      playerId: playerId,
      timestamp: detectedAt,
      direction: direction,
      power: power,
      durationMs: durationMs,
    );
  }
}
