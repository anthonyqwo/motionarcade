enum SensitivityLevel { low, medium, high }

class SensitivitySettings {
  const SensitivitySettings({
    required this.level,
    required this.swingThreshold,
    required this.forwardBackwardThreshold,
    required this.maxMagnitude,
    required this.cooldown,
  });

  factory SensitivitySettings.forLevel(SensitivityLevel level) {
    return switch (level) {
      SensitivityLevel.low => const SensitivitySettings(
        level: SensitivityLevel.low,
        swingThreshold: 10,
        forwardBackwardThreshold: 22,
        maxMagnitude: 28,
        cooldown: Duration(milliseconds: 380),
      ),
      SensitivityLevel.medium => const SensitivitySettings(
        level: SensitivityLevel.medium,
        swingThreshold: 7,
        forwardBackwardThreshold: 18,
        maxMagnitude: 24,
        cooldown: Duration(milliseconds: 300),
      ),
      SensitivityLevel.high => const SensitivitySettings(
        level: SensitivityLevel.high,
        swingThreshold: 4.5,
        forwardBackwardThreshold: 14,
        maxMagnitude: 18,
        cooldown: Duration(milliseconds: 240),
      ),
    };
  }

  final SensitivityLevel level;
  final double swingThreshold;
  final double forwardBackwardThreshold;
  final double maxMagnitude;
  final Duration cooldown;
}
