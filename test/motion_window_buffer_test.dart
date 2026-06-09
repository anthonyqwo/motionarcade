import 'package:flutter_test/flutter_test.dart';
import 'package:motionarcade/controller/motion_window_buffer.dart';
import 'package:motionarcade/shared/models/fused_motion_sample.dart';

void main() {
  FusedMotionSample createSample(DateTime time, {double userAccY = 0.0}) {
    return FusedMotionSample(
      attitude: QuaternionSample.identity,
      gravity: const Vector3Sample(x: 0, y: -9.8, z: 0),
      userAcceleration: Vector3Sample(x: 0, y: userAccY, z: 0),
      rotationRate: const Vector3Sample(x: 0, y: 0, z: 0),
      timestamp: time,
      source: 'test',
    );
  }

  group('MotionWindowBuffer', () {
    test('adds samples and respects capacity limit', () {
      final buffer = MotionWindowBuffer(capacity: 3);
      expect(buffer.isEmpty, isTrue);
      expect(buffer.length, 0);

      final t0 = DateTime.fromMillisecondsSinceEpoch(1000);
      final s1 = createSample(t0);
      final s2 = createSample(t0.add(const Duration(milliseconds: 16)));
      final s3 = createSample(t0.add(const Duration(milliseconds: 32)));
      final s4 = createSample(t0.add(const Duration(milliseconds: 48)));

      buffer.add(s1);
      expect(buffer.isEmpty, isFalse);
      expect(buffer.length, 1);

      buffer.add(s2);
      buffer.add(s3);
      expect(buffer.length, 3);
      expect(buffer.allSamples, [s1, s2, s3]);

      // Adding the 4th sample should roll over and remove the 1st sample
      buffer.add(s4);
      expect(buffer.length, 3);
      expect(buffer.allSamples, [s2, s3, s4]);
    });

    test('clears correctly', () {
      final buffer = MotionWindowBuffer(capacity: 3);
      final t0 = DateTime.fromMillisecondsSinceEpoch(1000);
      buffer.add(createSample(t0));
      buffer.add(createSample(t0.add(const Duration(milliseconds: 16))));

      expect(buffer.length, 2);
      buffer.clear();
      expect(buffer.length, 0);
      expect(buffer.isEmpty, isTrue);
      expect(buffer.allSamples, isEmpty);
    });

    test('retrieves snapshot covering correct duration', () {
      final buffer = MotionWindowBuffer(capacity: 10);
      final t0 = DateTime.fromMillisecondsSinceEpoch(1000);

      // Add 6 samples with 100ms intervals (total 500ms span)
      final samples = List.generate(6, (i) {
        return createSample(t0.add(Duration(milliseconds: i * 100)));
      });

      for (final s in samples) {
        buffer.add(s);
      }

      expect(buffer.length, 6);

      // Snapshot covering last 250ms should include indices 3 (300ms), 4 (400ms), 5 (500ms)
      // because 500 - 250 = 250, so samples with t >= 250ms.
      final snapshot = buffer.getWindowSnapshot(250);
      expect(snapshot.length, 3);
      expect(snapshot[0].timestamp.difference(t0).inMilliseconds, 300);
      expect(snapshot[1].timestamp.difference(t0).inMilliseconds, 400);
      expect(snapshot[2].timestamp.difference(t0).inMilliseconds, 500);

      // Snapshot covering last 1000ms should include all 6 samples
      final fullSnapshot = buffer.getWindowSnapshot(1000);
      expect(fullSnapshot.length, 6);
    });
  });
}
