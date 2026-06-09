import '../../shared/models/motion_event.dart';

enum SaberTargetStatus {
  active,
  cutPerfect,
  cutGood,
  cutWeak,
  missed,
}

class SaberTarget {
  SaberTarget({
    required this.id,
    required this.direction,
    required this.lane,
    required this.spawnTime,
    this.depth = 0.0,
    this.status = SaberTargetStatus.active,
    this.cutProgress = 0.0,
    this.cutAngle = 0.0,
  });

  final String id;
  final MotionDirection direction;
  final double lane; // -1.0 for Left, 0.0 for Center, 1.0 for Right
  final DateTime spawnTime;
  double depth; // 0.0 (far) to 1.0 (near/hit zone)
  SaberTargetStatus status;
  double cutProgress; // 0.0 (uncut) to 1.0 (fully split)
  double cutAngle; // Angle at which the block was cut (for split visual orientation)

  bool get isCut =>
      status == SaberTargetStatus.cutPerfect ||
      status == SaberTargetStatus.cutGood ||
      status == SaberTargetStatus.cutWeak;

  void update(double dt, double speed) {
    if (status == SaberTargetStatus.active) {
      depth += dt * speed;
    } else if (isCut) {
      cutProgress += dt * 3.5;
      if (cutProgress > 1.0) cutProgress = 1.0;
    }
  }
}
