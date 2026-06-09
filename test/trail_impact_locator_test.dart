import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motionarcade/shared/models/motion_event.dart';
import 'package:motionarcade/shared/visual/trail_impact_locator.dart';
import 'package:motionarcade/shared/visual/trail_renderer.dart';

void main() {
  group('TrailImpactLocator', () {
    test('locates the closest trail point for a slash', () {
      const locator = TrailImpactLocator();
      final slashTime = DateTime.fromMillisecondsSinceEpoch(1000);
      final slash = SlashEvent(
        playerId: 'p1',
        timestamp: slashTime,
        direction: MotionDirection.right,
        power: 0.7,
        durationMs: 100,
      );

      final origin = locator.locate(
        slash: slash,
        points: [
          TrailRenderPoint(
            playerId: 'p1',
            tipX: -1,
            tipY: -1,
            strength: 1,
            timestamp: slashTime.subtract(const Duration(milliseconds: 300)),
          ),
          TrailRenderPoint(
            playerId: 'p1',
            tipX: 0.5,
            tipY: 0.25,
            strength: 2,
            timestamp: slashTime.add(const Duration(milliseconds: 16)),
          ),
          TrailRenderPoint(
            playerId: 'other',
            tipX: -0.5,
            tipY: -0.5,
            strength: 2,
            timestamp: slashTime,
          ),
        ],
        size: const Size(200, 100),
      );

      expect(origin.dx, closeTo(100 + 0.5 * 100 * 0.72, 0.001));
      expect(origin.dy, closeTo(50 - 0.25 * 50 * 0.72, 0.001));
    });

    test('falls back to center when no nearby point exists', () {
      const locator = TrailImpactLocator();
      final slashTime = DateTime.fromMillisecondsSinceEpoch(1000);
      final slash = SlashEvent(
        playerId: 'p1',
        timestamp: slashTime,
        direction: MotionDirection.right,
        power: 0.7,
        durationMs: 100,
      );

      final origin = locator.locate(
        slash: slash,
        points: [
          TrailRenderPoint(
            playerId: 'p1',
            tipX: 1,
            tipY: 1,
            strength: 1,
            timestamp: slashTime.subtract(const Duration(seconds: 1)),
          ),
        ],
        size: const Size(200, 100),
      );

      expect(origin, const Offset(100, 50));
    });
  });
}
