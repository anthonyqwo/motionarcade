import '../../shared/models/motion_event.dart';

enum SaberTargetStatus { active, cutPerfect, cutGood, cutWeak, missed }

class SaberTarget {
  SaberTarget({
    required this.id,
    required this.direction,
    required this.lane,
    required this.spawnTime,
    double row = 0.0,
    this.depth = 0.0,
    this.status = SaberTargetStatus.active,
    this.cutProgress = 0.0,
    this.cutAngle = 0.0,
    double missProgress = 0.0,
  }) : _row = row,
       _missProgress = missProgress;

  final String id;
  final MotionDirection direction;
  final double lane; // -1.0 for Left, 0.0 for Center, 1.0 for Right
  final DateTime spawnTime;
  double depth; // 0.0 (far) to 1.0 (near/hit zone)
  SaberTargetStatus status;
  double cutProgress; // 0.0 (uncut) to 1.0 (fully split)
  // Angle at which the block was cut, used for split visual orientation.
  double cutAngle;
  double? _row;
  double? _missProgress;

  // -1.0 for upper targets, 0.0 center, 1.0 lower targets.
  double get row => _row ?? 0.0;

  // 0.0 (fresh miss) to 1.0 (fully faded).
  double get missProgress => _missProgress ?? 0.0;
  set missProgress(double value) => _missProgress = value;

  bool get isCut =>
      status == SaberTargetStatus.cutPerfect ||
      status == SaberTargetStatus.cutGood ||
      status == SaberTargetStatus.cutWeak;

  bool get isMissed => status == SaberTargetStatus.missed;

  bool get isFinished =>
      (isCut && cutProgress >= 1.0) || (isMissed && missProgress >= 1.0);

  void markMissed() {
    status = SaberTargetStatus.missed;
    missProgress = 0.0;
    depth = depth.clamp(0.0, 1.0);
  }

  void update(double dt, double speed) {
    if (status == SaberTargetStatus.active) {
      depth += dt * speed;
    } else if (isCut) {
      cutProgress += dt * 3.5;
      if (cutProgress > 1.0) cutProgress = 1.0;
    } else if (isMissed) {
      missProgress += dt / 0.72;
      if (missProgress > 1.0) missProgress = 1.0;
    }
  }
}
