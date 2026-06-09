import 'package:flutter/material.dart';

import '../models/motion_event.dart';
import 'trail_renderer.dart';

class TrailImpactLocator {
  const TrailImpactLocator({this.projection = const TrailProjection()});

  final TrailProjection projection;

  Offset locate({
    required SlashEvent slash,
    required List<TrailRenderPoint> points,
    required Size size,
  }) {
    TrailRenderPoint? closestPoint;
    var closestDistanceMs = 1 << 30;

    for (final point in points) {
      if (point.playerId != slash.playerId) {
        continue;
      }
      final distanceMs = point.timestamp
          .difference(slash.timestamp)
          .inMilliseconds
          .abs();
      if (distanceMs < closestDistanceMs) {
        closestDistanceMs = distanceMs;
        closestPoint = point;
      }
    }

    final point = closestPoint;
    if (point == null || closestDistanceMs > 360) {
      return Offset(size.width * 0.5, size.height * 0.5);
    }

    return projection.project(tipX: point.tipX, tipY: point.tipY, size: size);
  }
}
