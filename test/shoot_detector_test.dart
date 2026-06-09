import 'package:flutter_test/flutter_test.dart';
import 'package:motionarcade/controller/shoot_detector.dart';
import 'package:motionarcade/shared/models/fused_motion_sample.dart';

void main() {
  group('ShootDetector', () {
    const detector = ShootDetector();

    test('creates a shoot event from a clear upward throw', () {
      final samples = _samples(
        count: 32,
        xForIndex: (i) => i < 16 ? 0.05 : -0.02,
        yForIndex: (i) => i < 22 ? 1.25 : 0.35,
        zForIndex: (_) => 0.18,
      );

      final result = detector.detect(
        samples: samples,
        holdDurationMs: 620,
        playerId: 'p1',
        timestamp: DateTime.fromMillisecondsSinceEpoch(1000),
      );

      expect(result.isValid, isTrue);
      expect(result.event, isNotNull);
      expect(result.event!.power, greaterThan(0));
      expect(result.event!.angle, inInclusiveRange(32, 62));
      expect(result.event!.offset.abs(), lessThan(0.15));
      expect(result.event!.holdDurationMs, 620);
    });

    test('accepts quick press release when motion is valid', () {
      final result = detector.detect(
        samples: _samples(count: 20),
        holdDurationMs: 24,
        playerId: 'p1',
      );

      expect(result.isValid, isTrue);
      expect(result.event?.holdDurationMs, 24);
    });

    test('rejects releases without enough motion data', () {
      final result = detector.detect(
        samples: _samples(count: 2),
        holdDurationMs: 24,
        playerId: 'p1',
      );

      expect(result.isValid, isFalse);
      expect(result.reason, contains('data'));
    });

    test('rejects mostly sideways throws', () {
      final result = detector.detect(
        samples: _samples(
          count: 30,
          xForIndex: (_) => 1.4,
          yForIndex: (_) => 0.28,
          zForIndex: (_) => 0.05,
        ),
        holdDurationMs: 560,
        playerId: 'p1',
      );

      expect(result.isValid, isFalse);
      expect(result.reason, contains('sideways'));
    });

    test('maps lateral drift to shot offset', () {
      final left = detector.detect(
        samples: _samples(
          count: 30,
          xForIndex: (_) => -0.22,
          yForIndex: (_) => 1.1,
          zForIndex: (_) => 0.12,
        ),
        holdDurationMs: 560,
        playerId: 'p1',
      );
      final right = detector.detect(
        samples: _samples(
          count: 30,
          xForIndex: (_) => 0.22,
          yForIndex: (_) => 1.1,
          zForIndex: (_) => 0.12,
        ),
        holdDurationMs: 560,
        playerId: 'p1',
      );

      expect(left.isValid, isTrue);
      expect(right.isValid, isTrue);
      expect(left.event!.offset, lessThan(0));
      expect(right.event!.offset, greaterThan(0));
    });
  });
}

List<FusedMotionSample> _samples({
  required int count,
  double Function(int index)? xForIndex,
  double Function(int index)? yForIndex,
  double Function(int index)? zForIndex,
}) {
  final start = DateTime.fromMillisecondsSinceEpoch(1000);
  return [
    for (var i = 0; i < count; i++)
      FusedMotionSample(
        attitude: QuaternionSample.identity,
        gravity: const Vector3Sample(x: 0, y: -1, z: 0),
        userAcceleration: Vector3Sample(
          x: xForIndex?.call(i) ?? 0.04,
          y: yForIndex?.call(i) ?? 1.0,
          z: zForIndex?.call(i) ?? 0.12,
        ),
        rotationRate: const Vector3Sample(x: 0, y: 0, z: 0),
        timestamp: start.add(Duration(milliseconds: i * 16)),
        source: 'test',
      ),
  ];
}
