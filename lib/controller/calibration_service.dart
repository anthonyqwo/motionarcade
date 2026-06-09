import '../shared/models/motion_event.dart';
import '../shared/models/fused_motion_sample.dart';
import '../shared/models/sensor_sample.dart';

class CalibrationService {
  NeutralPosition? _neutral;
  SensorSample? _accelerometerBaseline;
  QuaternionSample? _initialAttitude;
  ControllerGripFrame? _gripFrame;

  NeutralPosition? get neutral => _neutral;
  SensorSample? get accelerometerBaseline => _accelerometerBaseline;
  QuaternionSample? get initialAttitude => _initialAttitude;
  ControllerGripFrame? get gripFrame => _gripFrame;
  bool get isCalibrated => _neutral != null || _initialAttitude != null;

  NeutralPosition? calibrate(MotionSensorSnapshot snapshot) {
    final gyroscope = snapshot.gyroscope;
    final accelerometer = snapshot.accelerometer;
    if (gyroscope == null || accelerometer == null) {
      return null;
    }

    _accelerometerBaseline = accelerometer;
    _neutral = NeutralPosition(
      pitch: gyroscope.x,
      roll: gyroscope.z,
      yaw: gyroscope.y,
    );
    return _neutral;
  }

  NeutralPosition calibrateFusedMotion(FusedMotionSample sample) {
    _initialAttitude = sample.attitude.normalized;
    _gripFrame = ControllerGripFrame.knifeSideDown(sample.gravity);
    _neutral = NeutralPosition(
      pitch: sample.rotationRate.x,
      roll: sample.rotationRate.z,
      yaw: sample.rotationRate.y,
    );
    return _neutral!;
  }

  FusedMotionSample applyToFusedMotion(FusedMotionSample sample) {
    final initialAttitude = _initialAttitude;
    if (initialAttitude == null) {
      return sample;
    }

    final controllerSample = sample.toControllerFrame(initialAttitude);
    final gripFrame = _gripFrame;
    if (gripFrame == null) {
      return controllerSample;
    }

    return controllerSample.toGripFrame(gripFrame);
  }

  SensorSample applyToAccelerometer(SensorSample sample) {
    final baseline = _accelerometerBaseline;
    if (baseline == null) {
      return sample;
    }

    return SensorSample(
      x: sample.x - baseline.x,
      y: sample.y - baseline.y,
      z: sample.z - baseline.z,
      timestamp: sample.timestamp,
    );
  }

  SensorSample applyToGyroscope(SensorSample sample) {
    final neutral = _neutral;
    if (neutral == null) {
      return sample;
    }

    return SensorSample(
      x: sample.x - neutral.pitch,
      y: sample.y - neutral.yaw,
      z: sample.z - neutral.roll,
      timestamp: sample.timestamp,
    );
  }
}
