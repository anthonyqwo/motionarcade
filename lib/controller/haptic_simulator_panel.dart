import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../shared/models/motion_event.dart';
import 'haptic_feedback_service.dart';

class HapticSimulatorPanel extends StatefulWidget {
  const HapticSimulatorPanel({super.key});

  @override
  State<HapticSimulatorPanel> createState() => _HapticSimulatorPanelState();
}

class _HapticSimulatorPanelState extends State<HapticSimulatorPanel>
    with SingleTickerProviderStateMixin {
  double _intensity = 0.5;
  double _sharpness = 0.5;
  double _duration = 0.1;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  void _triggerPulse(double durationSec) {
    _pulseController.duration = Duration(
      milliseconds: (durationSec * 1000).round().clamp(150, 1000),
    );
    _pulseController.forward(from: 0).then((_) {
      if (mounted) {
        _pulseController.reverse();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.vibration, color: theme.colorScheme.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Haptic Simulator',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                ScaleTransition(
                  scale: Tween<double>(begin: 1.0, end: 1.4).animate(
                    CurvedAnimation(
                      parent: _pulseController,
                      curve: Curves.easeOut,
                    ),
                  ),
                  child: Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: theme.colorScheme.primary.withValues(alpha: 0.8),
                      boxShadow: [
                        BoxShadow(
                          color: theme.colorScheme.primary.withValues(
                            alpha: 0.4,
                          ),
                          blurRadius: 8,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              height: 60,
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: CustomPaint(
                  painter: _HapticWaveformPainter(
                    intensity: _intensity,
                    sharpness: _sharpness,
                    duration: _duration,
                  ),
                  child: Container(),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Intensity: ${(_intensity * 100).round()}%',
              style: theme.textTheme.labelMedium,
            ),
            Slider(
              value: _intensity,
              onChanged: (v) => setState(() => _intensity = v),
              min: 0.0,
              max: 1.0,
            ),
            Text(
              'Sharpness (Frequency): ${(_sharpness * 100).round()}%',
              style: theme.textTheme.labelMedium,
            ),
            Slider(
              value: _sharpness,
              onChanged: (v) => setState(() => _sharpness = v),
              min: 0.0,
              max: 1.0,
            ),
            Text(
              'Duration: ${(_duration * 1000).round()}ms',
              style: theme.textTheme.labelMedium,
            ),
            Slider(
              value: _duration,
              onChanged: (v) => setState(() => _duration = v),
              min: 0.0,
              max: 1.0,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () {
                      unawaited(
                        HapticFeedbackService.playCustom(
                          intensity: _intensity,
                          sharpness: _sharpness,
                          duration: _duration,
                        ),
                      );
                      _triggerPulse(_duration);
                    },
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('Play Custom'),
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            Text('Preset Tactile Feedback', style: theme.textTheme.titleMedium),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _PresetButton(
                  label: 'Perfect',
                  color: Colors.green,
                  onPressed: () {
                    unawaited(
                      HapticFeedbackService.trigger(HapticPattern.perfect),
                    );
                    _triggerPulse(0.1);
                  },
                ),
                _PresetButton(
                  label: 'Good',
                  color: Colors.cyan,
                  onPressed: () {
                    unawaited(
                      HapticFeedbackService.trigger(HapticPattern.good),
                    );
                    _triggerPulse(0.08);
                  },
                ),
                _PresetButton(
                  label: 'Miss',
                  color: Colors.red,
                  onPressed: () {
                    unawaited(
                      HapticFeedbackService.trigger(HapticPattern.miss),
                    );
                    _triggerPulse(0.15);
                  },
                ),
                _PresetButton(
                  label: 'Combo',
                  color: Colors.orange,
                  onPressed: () {
                    unawaited(
                      HapticFeedbackService.trigger(HapticPattern.combo),
                    );
                    _triggerPulse(0.3);
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PresetButton extends StatelessWidget {
  const _PresetButton({
    required this.label,
    required this.color,
    required this.onPressed,
  });

  final String label;
  final Color color;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      style: OutlinedButton.styleFrom(
        foregroundColor: color,
        side: BorderSide(color: color.withValues(alpha: 0.5)),
      ),
      onPressed: onPressed,
      child: Text(label),
    );
  }
}

class _HapticWaveformPainter extends CustomPainter {
  _HapticWaveformPainter({
    required this.intensity,
    required this.sharpness,
    required this.duration,
  });

  final double intensity;
  final double sharpness;
  final double duration;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.blue.withValues(alpha: 0.3)
      ..style = PaintingStyle.fill;

    final gridPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.1)
      ..strokeWidth = 1;
    for (var i = 1; i < 4; i++) {
      final x = size.width * i / 4;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }

    final pulseWidth = (duration * size.width * 0.8).clamp(
      10.0,
      size.width * 0.9,
    );
    final pulseHeight = intensity * size.height * 0.8;
    final startX = (size.width - pulseWidth) / 2;
    final startY = (size.height - pulseHeight) / 2;

    final rect = Rect.fromLTWH(startX, startY, pulseWidth, pulseHeight);
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(4));

    final gradient = LinearGradient(
      colors: [
        Colors.blue.withValues(alpha: 0.2 + 0.6 * sharpness),
        Colors.purple.withValues(alpha: 0.4 + 0.5 * intensity),
      ],
    ).createShader(rect);

    paint.shader = gradient;
    canvas.drawRRect(rrect, paint);

    if (intensity > 0) {
      final wavePaint = Paint()
        ..color = Colors.white.withValues(alpha: 0.7)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;

      final path = Path();
      final pointsCount = (pulseWidth * 2).round();
      final waveFrequency = 5 + 25 * sharpness;

      var first = true;
      for (var i = 0; i <= pointsCount; i++) {
        final x = startX + (i / pointsCount) * pulseWidth;
        final relativeX = i / pointsCount;
        final edgeFade = math.sin(relativeX * math.pi);
        final y =
            (size.height / 2) +
            math.sin(relativeX * waveFrequency * math.pi) *
                (pulseHeight / 2) *
                edgeFade;

        if (first) {
          path.moveTo(x, y);
          first = false;
        } else {
          path.lineTo(x, y);
        }
      }
      canvas.drawPath(path, wavePaint);
    }
  }

  @override
  bool shouldRepaint(_HapticWaveformPainter oldDelegate) {
    return oldDelegate.intensity != intensity ||
        oldDelegate.sharpness != sharpness ||
        oldDelegate.duration != duration;
  }
}
