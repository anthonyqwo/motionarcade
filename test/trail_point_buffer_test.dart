import 'package:flutter_test/flutter_test.dart';
import 'package:motionarcade/shared/models/motion_event.dart';
import 'package:motionarcade/shared/models/motion_trail_sample.dart';
import 'package:motionarcade/shared/visual/trail_point_buffer.dart';

void main() {
  group('TrailPointBuffer', () {
    test('adds trail event samples on the normalized host timeline', () {
      final reference = DateTime.fromMillisecondsSinceEpoch(1000);
      final buffer = TrailPointBuffer();

      buffer.addEvent(
        MotionTrailEvent(
          playerId: 'p1',
          timestamp: reference.add(const Duration(milliseconds: 32)),
          referenceTimestamp: reference,
          samples: const [
            MotionTrailSample(tMs: 0, tipX: 0, tipY: 0, strength: 1),
            MotionTrailSample(tMs: 32, tipX: 0.5, tipY: 0.2, strength: 2),
          ],
        ),
        now: reference.add(const Duration(milliseconds: 32)),
      );

      expect(buffer.points, hasLength(2));
      expect(buffer.points.first.timestamp, reference);
      expect(
        buffer.points.last.timestamp,
        reference.add(const Duration(milliseconds: 32)),
      );
    });

    test('prunes old samples and caps total point count', () {
      final t0 = DateTime.fromMillisecondsSinceEpoch(1000);
      final buffer = TrailPointBuffer(
        retention: const Duration(milliseconds: 100),
        maxPoints: 3,
      );

      for (var i = 0; i < 5; i++) {
        final timestamp = t0.add(Duration(milliseconds: i * 20));
        buffer.addEvent(
          MotionTrailEvent(
            playerId: 'p1',
            timestamp: timestamp,
            referenceTimestamp: timestamp,
            samples: [
              MotionTrailSample(
                tMs: 0,
                tipX: i.toDouble(),
                tipY: 0,
                strength: 1,
              ),
            ],
          ),
          now: timestamp,
        );
      }

      expect(buffer.points, hasLength(3));
      expect(buffer.points.first.tipX, 2);

      buffer.prune(t0.add(const Duration(milliseconds: 220)));

      expect(buffer.points, isEmpty);
    });
  });
}
