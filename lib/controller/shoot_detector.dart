import 'dart:math' as math;

import '../games/basketball/shot_motion_features.dart';
import '../shared/models/fused_motion_sample.dart';
import '../shared/models/motion_event.dart';

class ShootDetector {
  const ShootDetector({
    this.minHoldDurationMs = 0,
    this.minSamples = 6,
    this.minUpwardEnergy = 0.16,
    this.minPeakMagnitude = 0.34,
    this.maxHorizontalNoise = 0.42,
    this.powerEnergyRange = 1.12,
  });

  final int minHoldDurationMs;
  final int minSamples;
  final double minUpwardEnergy;
  final double minPeakMagnitude;
  final double maxHorizontalNoise;
  final double powerEnergyRange;

  ShootDetectionResult detect({
    required List<FusedMotionSample> samples,
    required int holdDurationMs,
    required String playerId,
    DateTime? timestamp,
  }) {
    final features = analyze(samples);
    if (holdDurationMs < minHoldDurationMs) {
      return ShootDetectionResult.invalid(
        reason: 'Hold a little longer',
        features: features,
      );
    }
    if (samples.length < minSamples) {
      return ShootDetectionResult.invalid(
        reason: 'Not enough motion data',
        features: features,
      );
    }
    if (features.horizontalNoise > maxHorizontalNoise) {
      return ShootDetectionResult.invalid(
        reason: 'Too much sideways motion',
        features: features,
      );
    }
    if (features.upwardEnergy < minUpwardEnergy) {
      return ShootDetectionResult.invalid(
        reason: 'Throw upward more clearly',
        features: features,
      );
    }
    if (features.peakMagnitude < minPeakMagnitude) {
      return ShootDetectionResult.invalid(
        reason: 'Shot was too light',
        features: features,
      );
    }

    final rawPower =
        ((features.upwardEnergy - minUpwardEnergy) /
                (powerEnergyRange - minUpwardEnergy))
            .clamp(0.0, 1.0)
            .toDouble();
    final power = (1 - math.pow(1 - rawPower, 1.35)).toDouble().clamp(0.0, 1.0);
    final angleRadians = math.atan2(
      math.max(0.001, features.releasePeakY),
      features.releasePeakZ.abs() + 0.18,
    );
    final angle = (angleRadians * 180 / math.pi).clamp(32.0, 62.0).toDouble();
    final offset =
        (features.lateralDrift / (features.upwardEnergy + 0.0001) * 1.35)
            .clamp(-1.0, 1.0)
            .toDouble();

    return ShootDetectionResult.valid(
      event: ShootEvent(
        playerId: playerId,
        timestamp: timestamp ?? DateTime.now(),
        power: power,
        angle: angle,
        offset: offset,
        stability: features.stability,
        holdDurationMs: holdDurationMs,
      ),
      features: features,
    );
  }

  ShotMotionFeatures analyze(List<FusedMotionSample> samples) {
    if (samples.isEmpty) {
      return const ShotMotionFeatures(
        upwardEnergy: 0,
        totalEnergy: 0,
        horizontalNoise: 0,
        lateralDrift: 0,
        peakMagnitude: 0,
        releasePeakY: 0,
        releasePeakZ: 0,
        stability: 0,
        sampleCount: 0,
      );
    }

    var upwardEnergy = 0.0;
    var totalEnergy = 0.0;
    var horizontalEnergy = 0.0;
    var lateralDrift = 0.0;
    var peakMagnitude = 0.0;
    var releasePeakY = 0.0;
    var releasePeakZ = 0.0;
    var positiveYFrames = 0;

    for (var i = 0; i < samples.length; i++) {
      final sample = samples[i];
      final acceleration = sample.userAcceleration;
      final dt = _sampleSeconds(samples, i);
      final magnitude = acceleration.magnitude;
      final positiveY = math.max(0.0, acceleration.y);

      upwardEnergy += positiveY * dt;
      totalEnergy += magnitude * dt;
      horizontalEnergy += acceleration.x.abs() * dt;
      lateralDrift += acceleration.x * dt;
      if (positiveY > 0) {
        positiveYFrames++;
      }

      if (positiveY > releasePeakY || magnitude > peakMagnitude) {
        peakMagnitude = math.max(peakMagnitude, magnitude);
        if (positiveY > releasePeakY) {
          releasePeakY = positiveY;
          releasePeakZ = acceleration.z;
        }
      }
    }

    final horizontalNoise = totalEnergy <= 0
        ? 0.0
        : (horizontalEnergy / totalEnergy).clamp(0.0, 1.0).toDouble();
    final positiveRatio = positiveYFrames / samples.length;
    final upwardRatio = totalEnergy <= 0
        ? 0.0
        : (upwardEnergy / totalEnergy).clamp(0.0, 1.0).toDouble();
    final stability =
        (positiveRatio * 0.45 + upwardRatio * 0.75 - horizontalNoise * 0.35)
            .clamp(0.0, 1.0)
            .toDouble();

    return ShotMotionFeatures(
      upwardEnergy: upwardEnergy,
      totalEnergy: totalEnergy,
      horizontalNoise: horizontalNoise,
      lateralDrift: lateralDrift,
      peakMagnitude: peakMagnitude,
      releasePeakY: releasePeakY,
      releasePeakZ: releasePeakZ,
      stability: stability,
      sampleCount: samples.length,
    );
  }

  double _sampleSeconds(List<FusedMotionSample> samples, int index) {
    if (samples.length < 2) {
      return 1 / 60;
    }
    final current = samples[index].timestamp;
    final previous = index == 0
        ? samples[index + 1].timestamp
        : samples[index - 1].timestamp;
    final ms = current.difference(previous).inMilliseconds.abs();
    if (ms <= 0) {
      return 1 / 60;
    }
    return (ms / 1000).clamp(0.008, 0.04).toDouble();
  }
}

class ShootDetectionResult {
  const ShootDetectionResult._({
    required this.isValid,
    required this.reason,
    required this.features,
    this.event,
  });

  factory ShootDetectionResult.valid({
    required ShootEvent event,
    required ShotMotionFeatures features,
  }) {
    return ShootDetectionResult._(
      isValid: true,
      reason: 'Shot released',
      features: features,
      event: event,
    );
  }

  factory ShootDetectionResult.invalid({
    required String reason,
    required ShotMotionFeatures features,
  }) {
    return ShootDetectionResult._(
      isValid: false,
      reason: reason,
      features: features,
    );
  }

  final bool isValid;
  final String reason;
  final ShotMotionFeatures features;
  final ShootEvent? event;
}
