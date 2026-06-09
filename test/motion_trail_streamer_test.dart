import 'dart:math' as math;
import 'package:flutter_test/flutter_test.dart';
import 'package:motionarcade/controller/calibration_service.dart';
import 'package:motionarcade/controller/motion_trail_streamer.dart';
import 'package:motionarcade/shared/models/fused_motion_sample.dart';
import 'package:motionarcade/shared/models/motion_event.dart';

void main() {
  FusedMotionSample createSample({
    required DateTime time,
    QuaternionSample attitude = QuaternionSample.identity,
    double userAccY = 0.0,
    double rotationY = 0.0,
  }) {
    return FusedMotionSample(
      attitude: attitude,
      gravity: const Vector3Sample(x: 0, y: -9.8, z: 0),
      userAcceleration: Vector3Sample(x: 0, y: userAccY, z: 0),
      rotationRate: Vector3Sample(x: 0, y: rotationY, z: 0),
      timestamp: time,
      source: 'test',
    );
  }

  group('MotionTrailStreamer', () {
    test('defaults to active trail packets near 30Hz', () {
      final events = <MotionTrailEvent>[];
      final streamer = MotionTrailStreamer(
        playerId: 'p1',
        onEvent: events.add,
        alpha: 1.0,
      );

      final t0 = DateTime.fromMillisecondsSinceEpoch(1000);
      for (var i = 0; i < 10; i++) {
        streamer.onSample(
          createSample(
            time: t0.add(Duration(milliseconds: i * 16)),
            userAccY: 3.0,
          ),
        );
      }

      expect(events, hasLength(4));
      expect(events.first.timestamp, t0.add(const Duration(milliseconds: 32)));
    });

    test('treats low-acceleration rotation as active trail movement', () {
      final events = <MotionTrailEvent>[];
      final streamer = MotionTrailStreamer(
        playerId: 'p1',
        onEvent: events.add,
        downsampleRatio: 1,
        alpha: 1.0,
        idleThreshold: 2.0,
        rotationActiveThreshold: 0.2,
        activeIntervalMs: 33,
        idleIntervalMs: 200,
      );

      final t0 = DateTime.fromMillisecondsSinceEpoch(1000);
      streamer.onSample(createSample(time: t0, rotationY: 0.3));
      streamer.onSample(
        createSample(
          time: t0.add(const Duration(milliseconds: 40)),
          rotationY: 0.3,
        ),
      );

      expect(events, hasLength(1));
    });

    test('projects relative attitude correctly onto tipX and tipY', () {
      MotionTrailEvent? receivedEvent;
      final streamer = MotionTrailStreamer(
        playerId: 'p1',
        onEvent: (event) => receivedEvent = event,
        downsampleRatio: 1, // process all samples
        alpha: 1.0,        // no smoothing to verify raw projection
        idleThreshold: 0.0, // force active rate
        activeIntervalMs: 10,
      );

      final t0 = DateTime.fromMillisecondsSinceEpoch(1000);
      
      // Identity quaternion: tip should align with Y axis (0, 1, 0)
      streamer.onSample(createSample(
        time: t0,
        attitude: QuaternionSample.identity,
      ));

      // Trigger a packet send by passing a sample after the active interval
      streamer.onSample(createSample(
        time: t0.add(const Duration(milliseconds: 15)),
        attitude: QuaternionSample.identity,
      ));

      expect(receivedEvent, isNotNull);
      expect(receivedEvent!.samples.length, 2);
      expect(receivedEvent!.samples[0].tipX, 0.0);
      expect(receivedEvent!.samples[0].tipY, 1.0);
    });

    test('performs downsampling correctly', () {
      final events = <MotionTrailEvent>[];
      final streamer = MotionTrailStreamer(
        playerId: 'p1',
        onEvent: (e) => events.add(e),
        downsampleRatio: 2, // process every second sample
        alpha: 1.0,
        idleThreshold: 0.0,
        activeIntervalMs: 100,
      );

      final t0 = DateTime.fromMillisecondsSinceEpoch(1000);
      
      // Send 5 samples at 16ms intervals (total 64ms)
      for (int i = 0; i < 5; i++) {
        streamer.onSample(createSample(time: t0.add(Duration(milliseconds: i * 16))));
      }
      
      // Send a final sample at 116ms (greater than 100ms interval) to force sending
      streamer.onSample(createSample(time: t0.add(const Duration(milliseconds: 116))));

      expect(events.length, 1);
      // Samples processed: index 1, 3, 5 (since counter starts at 1 and processes 2, 4, 6)
      // Wait, counter increments on every call:
      // sample 1 (counter 1): skipped
      // sample 2 (counter 2): kept (t = 16)
      // sample 3 (counter 3): skipped
      // sample 4 (counter 4): kept (t = 48)
      // sample 5 (counter 5): skipped
      // sample 6 (counter 6, t = 116): kept (t = 116)
      // So batch has 3 samples.
      expect(events[0].samples.length, 3);
      expect(events[0].samples[0].tMs, 0); // first sample in batch is reference
      expect(events[0].samples[1].tMs, 32); // 48 - 16
      expect(events[0].samples[2].tMs, 100); // 116 - 16
    });

    test('implements adaptive rate based on acceleration threshold', () {
      final events = <MotionTrailEvent>[];
      final streamer = MotionTrailStreamer(
        playerId: 'p1',
        onEvent: (e) => events.add(e),
        downsampleRatio: 1,
        alpha: 1.0,
        idleThreshold: 2.0, // threshold 2.0 m/s2
        activeIntervalMs: 33,
        idleIntervalMs: 200,
      );

      final t0 = DateTime.fromMillisecondsSinceEpoch(1000);

      // --- Idle Phase: Acc = 0.5 (below 2.0) ---
      // Send samples at 20ms intervals up to 100ms
      for (int i = 0; i < 6; i++) {
        streamer.onSample(createSample(
          time: t0.add(Duration(milliseconds: i * 20)),
          userAccY: 0.5,
        ));
      }
      // Elapsed is 100ms. Since target interval is 200ms (idle), no packets should be sent yet.
      expect(events, isEmpty);

      // Advance to 200ms to trigger the idle packet
      streamer.onSample(createSample(
        time: t0.add(const Duration(milliseconds: 200)),
        userAccY: 0.5,
      ));
      expect(events.length, 1);
      events.clear();
      streamer.reset();

      // --- Active Phase: Acc = 3.0 (above 2.0) ---
      // Send samples at 20ms intervals
      streamer.onSample(createSample(
        time: t0,
        userAccY: 3.0,
      ));
      // Second sample at 40ms should trigger packet (elapsed 40ms > activeIntervalMs 33ms)
      streamer.onSample(createSample(
        time: t0.add(const Duration(milliseconds: 40)),
        userAccY: 3.0,
      ));

      expect(events.length, 1);
    });

    test('applies exponential smoothing to tipX and tipY', () {
      MotionTrailEvent? receivedEvent;
      final streamer = MotionTrailStreamer(
        playerId: 'p1',
        onEvent: (event) => receivedEvent = event,
        downsampleRatio: 1,
        alpha: 0.5, // 50% smoothing
        idleThreshold: 0.0,
        activeIntervalMs: 10,
      );

      final t0 = DateTime.fromMillisecondsSinceEpoch(1000);

      // Let's rotate reference vector using custom attitude
      // To keep it simple, we construct attitude that rotates (0, 1, 0) to (0.6, 0.8, 0)
      // Actually, we can just pass specific attitudes.
      // Quaternion for rotating about Z axis:
      // rotation about Z by theta: cos(theta/2) + sin(theta/2) k
      // Let's use simple QuaternionSample to verify EMA math:
      // First sample tipX is 0.0, tipY is 1.0 (identity attitude rotates (0, 1, 0) to (0, 1, 0))
      // So smoothedX = 0.0, smoothedY = 1.0.
      
      // Second sample: we use a quaternion that rotates (0, 1, 0) to something else.
      // E.g., QuaternionSample(x: 0, y: 0, z: sin(pi/4), w: cos(pi/4)) which is Z-rotation of 90 degrees.
      // It rotates (0, 1, 0) to (-1, 0, 0).
      // So newTipX = -1.0, newTipY = 0.0.
      // EMA with alpha = 0.5:
      // smoothedX = 0.0 * 0.5 + (-1.0) * 0.5 = -0.5
      // smoothedY = 1.0 * 0.5 + 0.0 * 0.5 = 0.5
      
      final rotZ90 = QuaternionSample(
        x: 0,
        y: 0,
        z: -0.70710678118, // sin(-45 deg)
        w: 0.70710678118,  // cos(-45 deg)
      );

      streamer.onSample(createSample(
        time: t0,
        attitude: QuaternionSample.identity,
      ));

      streamer.onSample(createSample(
        time: t0.add(const Duration(milliseconds: 20)),
        attitude: rotZ90,
      ));

      expect(receivedEvent, isNotNull);
      final samples = receivedEvent!.samples;
      expect(samples.length, 2);
      expect(samples[0].tipX, 0.0);
      expect(samples[0].tipY, 1.0);
      
      // Close approximation to 0.5 and 0.5
      expect(samples[1].tipX, closeTo(0.5, 0.01));
      expect(samples[1].tipY, closeTo(0.5, 0.01));
    });

    test('projects relative attitude onto calibrated grip frame', () {
      final calibrationService = CalibrationService();
      
      // Calibrate with neutral pose pointing forward, but tilted flat
      // gravity = (0, -9.8, 0)
      final neutralSample = FusedMotionSample(
        attitude: QuaternionSample.identity,
        gravity: const Vector3Sample(x: 0, y: -9.8, z: 0),
        userAcceleration: const Vector3Sample(x: 0, y: 0, z: 0),
        rotationRate: const Vector3Sample(x: 0, y: 0, z: 0),
        timestamp: DateTime.fromMillisecondsSinceEpoch(1000),
        source: 'test',
      );
      calibrationService.calibrateFusedMotion(neutralSample);
      
      MotionTrailEvent? receivedEvent;
      final streamer = MotionTrailStreamer(
        playerId: 'p1',
        onEvent: (event) => receivedEvent = event,
        downsampleRatio: 1,
        alpha: 1.0,
        idleThreshold: 0.0,
        activeIntervalMs: 10,
        calibrationService: calibrationService,
      );

      final t0 = DateTime.fromMillisecondsSinceEpoch(1000);
      
      // Let's rotate the phone UP (pitch up)
      // Since it's calibrated flat, tilting UP (around X axis) rotates Y towards Z.
      // E.g., Quaternion rotating +30 degrees around X.
      // Quaternion = (sin(15), 0, 0, cos(15)) = (0.2588, 0, 0, 0.9659)
      const pitchUp = QuaternionSample(x: 0.2588190451, y: 0, z: 0, w: 0.9659258263);
      
      // Let's process the sample
      streamer.onSample(createSample(
        time: t0,
        attitude: pitchUp,
      ));
      
      streamer.onSample(createSample(
        time: t0.add(const Duration(milliseconds: 15)),
        attitude: pitchUp,
      ));

      expect(receivedEvent, isNotNull);
      final samples = receivedEvent!.samples;
      
      // The rotated vector rotated = pitchUp.rotate((0, 1, 0))
      // With +30 deg rotation around X, (0, 1, 0) rotates to (0, cos(30), sin(30)) = (0, 0.866, 0.5)
      // Since calibration neutral had gravity along -Y, upAxis is +Y, forwardAxis is +Z, rightAxis is +X.
      // So projected onto grip frame is (x: 0, y: 0.866, z: 0.5).
      // Thus, tipX = 0, tipY = 0.866.
      expect(samples[0].tipX, closeTo(0.0, 0.01));
      expect(samples[0].tipY, closeTo(0.866, 0.01));
    });

    test('projects relative attitude onto calibrated knife grip frame', () {
      final calibrationService = CalibrationService();
      
      // Calibrate with neutral pose in knife grip (gravity along +X)
      // gravity = (9.8, 0, 0)
      final neutralSample = FusedMotionSample(
        attitude: QuaternionSample.identity,
        gravity: const Vector3Sample(x: 9.80665, y: 0, z: 0),
        userAcceleration: const Vector3Sample(x: 0, y: 0, z: 0),
        rotationRate: const Vector3Sample(x: 0, y: 0, z: 0),
        timestamp: DateTime.fromMillisecondsSinceEpoch(1000),
        source: 'test',
      );
      calibrationService.calibrateFusedMotion(neutralSample);
      
      MotionTrailEvent? receivedEvent;
      final streamer = MotionTrailStreamer(
        playerId: 'p1',
        onEvent: (event) => receivedEvent = event,
        downsampleRatio: 1,
        alpha: 1.0,
        idleThreshold: 0.0,
        activeIntervalMs: 10,
        calibrationService: calibrationService,
      );

      final t0 = DateTime.fromMillisecondsSinceEpoch(1000);
      
      // Let's simulate a physical pitch DOWN.
      // On the actual device, the native attitude is inverted, so a physical pitch down
      // returns a native Z rotation of +30 degrees.
      const pitchDown = QuaternionSample(x: 0, y: 0, z: 0.2588190451, w: 0.9659258263);
      
      streamer.onSample(createSample(
        time: t0,
        attitude: pitchDown,
      ));
      
      streamer.onSample(createSample(
        time: t0.add(const Duration(milliseconds: 15)),
        attitude: pitchDown,
      ));

      expect(receivedEvent, isNotNull);
      final samples = receivedEvent!.samples;
      
      // Rotated vector: rotated = pitchDown.rotate((0, 1, 0))
      // Since it is Z rotation of -30 deg: (0, 1, 0) rotates to (sin(30), cos(30), 0) = (0.5, 0.866, 0)
      // Since gravity = (9.8, 0, 0):
      // upAxis = (-1, 0, 0).
      // forwardAxis = (0, 0, 1).
      // rightAxis = (0, 1, 0).
      // projected = (x: 0.866, y: -0.5, z: 0)
      // Since it is sideways grip:
      // tipX = -projected.z = 0
      // tipY = projected.y = -0.5 (which is negative, i.e., moving DOWN on the screen!)
      expect(samples[0].tipX, closeTo(0.0, 0.01));
      expect(samples[0].tipY, closeTo(0.5, 0.01));
    });

    test('projects relative attitude onto calibrated knife grip frame with non-identity initial attitude', () {
      final calibrationService = CalibrationService();
      
      // Calibrate with neutral pose rotated 45 degrees around Y, in knife grip (gravity along +X)
      // gravity = (9.8, 0, 0)
      final halfTurnY = QuaternionSample(x: 0, y: math.sin(math.pi / 8), z: 0, w: math.cos(math.pi / 8));
      final neutralSample = FusedMotionSample(
        attitude: halfTurnY,
        gravity: const Vector3Sample(x: 9.80665, y: 0, z: 0),
        userAcceleration: const Vector3Sample(x: 0, y: 0, z: 0),
        rotationRate: const Vector3Sample(x: 0, y: 0, z: 0),
        timestamp: DateTime.fromMillisecondsSinceEpoch(1000),
        source: 'test',
      );
      calibrationService.calibrateFusedMotion(neutralSample);
      
      MotionTrailEvent? receivedEvent;
      final streamer = MotionTrailStreamer(
        playerId: 'p1',
        onEvent: (event) => receivedEvent = event,
        downsampleRatio: 1,
        alpha: 1.0,
        idleThreshold: 0.0,
        activeIntervalMs: 10,
        calibrationService: calibrationService,
      );

      final t0 = DateTime.fromMillisecondsSinceEpoch(1000);
      
      // Rotate the current attitude: relative rotation is a Z rotation of +30 degrees (pitch down)
      // Since relativeRotation = attitude * initialAttitude.inverse:
      // attitude = relativeRotation * initialAttitude
      final relativeRot = QuaternionSample(x: 0, y: 0, z: 0.2588190451, w: 0.9659258263); // Z rotation of +30 degrees
      final currentAttitude = halfTurnY * relativeRot;
      
      final rawSample = FusedMotionSample(
        attitude: currentAttitude,
        gravity: const Vector3Sample(x: 9.80665, y: 0, z: 0),
        userAcceleration: const Vector3Sample(x: 0, y: 0, z: 0),
        rotationRate: const Vector3Sample(x: 0, y: 0, z: 0),
        timestamp: t0,
        source: 'test',
      );
      
      // Apply calibration to get the controller sample
      final calibratedSample = calibrationService.applyToFusedMotion(rawSample);
      
      streamer.onSample(calibratedSample);
      
      // Force batch send
      final nextSample = FusedMotionSample(
        attitude: currentAttitude,
        gravity: const Vector3Sample(x: 9.80665, y: 0, z: 0),
        userAcceleration: const Vector3Sample(x: 0, y: 0, z: 0),
        rotationRate: const Vector3Sample(x: 0, y: 0, z: 0),
        timestamp: t0.add(const Duration(milliseconds: 15)),
        source: 'test',
      );
      streamer.onSample(calibrationService.applyToFusedMotion(nextSample));

      expect(receivedEvent, isNotNull);
      final samples = receivedEvent!.samples;
      
      // tipY = -0.5, tipX = 0.0
      expect(samples[0].tipX, closeTo(0.0, 0.01));
      expect(samples[0].tipY, closeTo(0.5, 0.01));
    });
  });
}
