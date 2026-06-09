import '../models/motion_event.dart';
import 'trail_renderer.dart';

class TrailPointBuffer {
  TrailPointBuffer({
    this.retention = const Duration(milliseconds: 900),
    this.maxPoints = 160,
    this.projection = const TrailProjection(),
  });

  final Duration retention;
  final int maxPoints;
  final TrailProjection projection;

  final List<TrailRenderPoint> _points = [];

  List<TrailRenderPoint> get points => _points;

  void addEvent(MotionTrailEvent event, {DateTime? now}) {
    for (final sample in event.samples) {
      _points.add(
        projection.fromSample(
          playerId: event.playerId,
          sample: sample,
          referenceTimestamp: event.referenceTimestamp,
        ),
      );
    }
    prune(now ?? DateTime.now());
  }

  void prune(DateTime now) {
    final cutoff = now.subtract(retention);
    _points.removeWhere((point) => point.timestamp.isBefore(cutoff));
    if (_points.length > maxPoints) {
      _points.removeRange(0, _points.length - maxPoints);
    }
  }

  void clear() {
    _points.clear();
  }
}
