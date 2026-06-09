class MotionTrailSample {
  const MotionTrailSample({
    required this.tMs,
    required this.tipX,
    required this.tipY,
    required this.strength,
  });

  factory MotionTrailSample.fromJson(Map<String, Object?> json) {
    return MotionTrailSample(
      tMs: json['tMs'] as int,
      tipX: (json['tipX'] as num).toDouble(),
      tipY: (json['tipY'] as num).toDouble(),
      strength: (json['strength'] as num).toDouble(),
    );
  }

  final int tMs;
  final double tipX;
  final double tipY;
  final double strength;

  Map<String, Object?> toJson() {
    return {
      'tMs': tMs,
      'tipX': tipX,
      'tipY': tipY,
      'strength': strength,
    };
  }
}
