import '../shared/models/fused_motion_sample.dart';
import '../shared/models/motion_event.dart';
import '../shared/models/motion_trail_sample.dart';
import 'calibration_service.dart';

class MotionTrailStreamer {
  MotionTrailStreamer({
    required this.playerId,
    required this.onEvent,
    this.downsampleRatio = 1,
    this.alpha = 0.3,
    this.idleThreshold = 1.5,
    this.rotationActiveThreshold = 0.2,
    this.tipDeltaActiveThreshold = 0.012,
    this.activeIntervalMs = 30,
    this.idleIntervalMs = 100,
    this.maxBatchSize = 12,
    this.calibrationService,
  }) : assert(downsampleRatio >= 1),
       assert(alpha > 0 && alpha <= 1),
       assert(activeIntervalMs > 0),
       assert(idleIntervalMs >= activeIntervalMs),
       assert(maxBatchSize >= 1);

  final String playerId;
  final void Function(MotionTrailEvent event) onEvent;
  final int downsampleRatio;
  final double alpha;
  final double idleThreshold;
  final double rotationActiveThreshold;
  final double tipDeltaActiveThreshold;
  final int activeIntervalMs;
  final int idleIntervalMs;
  final int maxBatchSize;
  final CalibrationService? calibrationService;

  final List<MotionTrailSample> _batch = [];
  DateTime? _referenceTimestamp;
  DateTime? _lastSentTime;
  int _sampleCounter = 0;

  double? _smoothedTipX;
  double? _smoothedTipY;
  double? _lastSentTipX;
  double? _lastSentTipY;

  /// Processes a new fused motion sample, downsampling and projecting it,
  /// and firing the onEvent callback when a packet interval has elapsed.
  void onSample(FusedMotionSample sample) {
    _sampleCounter++;

    // 1. Downsampling (e.g. 60Hz to 30Hz)
    if (_sampleCounter % downsampleRatio != 0) {
      return;
    }

    // 2. Vector projection: Rotate reference vector (0, 1, 0) by corrected attitude
    final correctedAttitude = sample.attitude;
    final rotated = correctedAttitude.rotate(const Vector3Sample(x: 0, y: 1, z: 0));
    final gripFrame = calibrationService?.gripFrame ?? ControllerGripFrame.flatTest;
    
    // Unified Projection Model: project the rotated pointing vector onto the physical screen axes
    final upAxis = gripFrame.upAxis;
    var rightAxis = const Vector3Sample(x: 0, y: 1, z: 0).cross(upAxis);
    if (rightAxis.magnitude < 0.001) {
      rightAxis = const Vector3Sample(x: 1, y: 0, z: 0);
    } else {
      rightAxis = rightAxis.normalized;
    }

    final double tipX = rotated.dot(rightAxis);
    final double tipY = rotated.dot(upAxis);
    final strength = sample.userAcceleration.magnitude;

    // 3. Smoothing (Exponential Moving Average)
    _smoothedTipX = _smoothedTipX == null
        ? tipX
        : _smoothedTipX! * (1 - alpha) + tipX * alpha;
    _smoothedTipY = _smoothedTipY == null
        ? tipY
        : _smoothedTipY! * (1 - alpha) + tipY * alpha;

    // 4. Batching
    if (_batch.isEmpty) {
      _referenceTimestamp = sample.timestamp;
    }

    final tMs = sample.timestamp.difference(_referenceTimestamp!).inMilliseconds;
    _batch.add(MotionTrailSample(
      tMs: tMs,
      tipX: _smoothedTipX!,
      tipY: _smoothedTipY!,
      strength: strength,
    ));

    // 5. Check if it's time to send based on adaptive rate
    _lastSentTime ??= sample.timestamp;
    final elapsedMs = sample.timestamp.difference(_lastSentTime!).inMilliseconds;

    final isActive =
        sample.motionMagnitude >= idleThreshold ||
        sample.rotationRate.magnitude >= rotationActiveThreshold ||
        _hasMovedSinceLastSend(_smoothedTipX!, _smoothedTipY!);
    final targetIntervalMs = isActive ? activeIntervalMs : idleIntervalMs;

    if ((elapsedMs >= targetIntervalMs || _batch.length >= maxBatchSize) &&
        _batch.isNotEmpty) {
      final event = MotionTrailEvent(
        playerId: playerId,
        timestamp: sample.timestamp,
        referenceTimestamp: _referenceTimestamp!,
        samples: List.from(_batch),
      );
      onEvent(event);

      _batch.clear();
      _referenceTimestamp = null;
      _lastSentTime = sample.timestamp;
      _lastSentTipX = _smoothedTipX;
      _lastSentTipY = _smoothedTipY;
    }
  }

  bool _hasMovedSinceLastSend(double tipX, double tipY) {
    final lastX = _lastSentTipX;
    final lastY = _lastSentTipY;
    if (lastX == null || lastY == null) {
      return false;
    }

    final dx = tipX - lastX;
    final dy = tipY - lastY;
    return dx * dx + dy * dy >=
        tipDeltaActiveThreshold * tipDeltaActiveThreshold;
  }

  /// Resets the streamer state.
  void reset() {
    _batch.clear();
    _referenceTimestamp = null;
    _lastSentTime = null;
    _sampleCounter = 0;
    _smoothedTipX = null;
    _smoothedTipY = null;
    _lastSentTipX = null;
    _lastSentTipY = null;
  }
}
