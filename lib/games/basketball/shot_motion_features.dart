class ShotMotionFeatures {
  const ShotMotionFeatures({
    required this.upwardEnergy,
    required this.totalEnergy,
    required this.horizontalNoise,
    required this.lateralDrift,
    required this.peakMagnitude,
    required this.releasePeakY,
    required this.releasePeakZ,
    required this.stability,
    required this.sampleCount,
  });

  final double upwardEnergy;
  final double totalEnergy;
  final double horizontalNoise;
  final double lateralDrift;
  final double peakMagnitude;
  final double releasePeakY;
  final double releasePeakZ;
  final double stability;
  final int sampleCount;
}
