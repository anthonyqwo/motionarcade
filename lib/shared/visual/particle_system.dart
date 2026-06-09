import 'dart:math' as math;

import 'package:flutter/material.dart';

class Particle {
  const Particle({
    required this.origin,
    required this.velocity,
    required this.color,
    required this.createdAt,
    this.lifetime = const Duration(milliseconds: 520),
    this.radius = 3,
  });

  final Offset origin;
  final Offset velocity;
  final Color color;
  final DateTime createdAt;
  final Duration lifetime;
  final double radius;

  bool isAlive(DateTime now) => now.difference(createdAt) < lifetime;

  double progress(DateTime now) {
    return (now.difference(createdAt).inMilliseconds / lifetime.inMilliseconds)
        .clamp(0.0, 1.0);
  }

  Offset positionAt(DateTime now) {
    final t = progress(now);
    return origin + velocity * t;
  }

  double opacityAt(DateTime now) => 1 - progress(now);
}

class ParticleBurstFactory {
  const ParticleBurstFactory();

  List<Particle> createBurst({
    required Offset origin,
    required DateTime now,
    required Color color,
    int count = 16,
    double speed = 34,
  }) {
    return [
      for (var i = 0; i < count; i++)
        Particle(
          origin: origin,
          velocity: Offset(
            math.cos((math.pi * 2 * i) / count) * speed,
            math.sin((math.pi * 2 * i) / count) * speed,
          ),
          color: color,
          createdAt: now,
        ),
    ];
  }
}

class ParticlePainter {
  const ParticlePainter();

  void paint(Canvas canvas, List<Particle> particles, DateTime now) {
    for (final particle in particles) {
      if (!particle.isAlive(now)) {
        continue;
      }
      final paint = Paint()
        ..color = particle.color.withValues(alpha: particle.opacityAt(now))
        ..style = PaintingStyle.fill;
      canvas.drawCircle(particle.positionAt(now), particle.radius, paint);
    }
  }
}
