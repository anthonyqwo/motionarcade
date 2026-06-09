import 'package:flutter/material.dart';

import '../shared/models/fused_motion_sample.dart';

class FusedMotionDebugPanel extends StatelessWidget {
  const FusedMotionDebugPanel({super.key, required this.snapshot});

  final FusedMotionSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sample = snapshot.controllerSample ?? snapshot.sample;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  snapshot.hasUsableSample ? Icons.track_changes : Icons.sync,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Fused Motion',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Text(snapshot.isActive ? 'Active' : 'Stopped'),
              ],
            ),
            if (snapshot.errorMessage != null) ...[
              const SizedBox(height: 12),
              Text(
                snapshot.errorMessage!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            ],
            const SizedBox(height: 14),
            _VectorRows(label: 'User Accel', vector: sample?.userAcceleration),
            const SizedBox(height: 10),
            _VectorRows(label: 'Rotation', vector: sample?.rotationRate),
            const SizedBox(height: 10),
            _QuaternionRows(quaternion: sample?.attitude),
            const Divider(height: 24),
            Row(
              children: [
                const Expanded(child: Text('Source')),
                Text(
                  sample?.source ?? '-',
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Expanded(child: Text('Motion magnitude')),
                Text(
                  sample?.motionMagnitude.toStringAsFixed(2) ?? '-',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _VectorRows extends StatelessWidget {
  const _VectorRows({required this.label, required this.vector});

  final String label;
  final Vector3Sample? vector;

  @override
  Widget build(BuildContext context) {
    return _ValueGrid(
      label: label,
      values: {
        'x': vector?.x,
        'y': vector?.y,
        'z': vector?.z,
        'mag': vector?.magnitude,
      },
    );
  }
}

class _QuaternionRows extends StatelessWidget {
  const _QuaternionRows({required this.quaternion});

  final QuaternionSample? quaternion;

  @override
  Widget build(BuildContext context) {
    return _ValueGrid(
      label: 'Attitude',
      values: {
        'x': quaternion?.x,
        'y': quaternion?.y,
        'z': quaternion?.z,
        'w': quaternion?.w,
      },
    );
  }
}

class _ValueGrid extends StatelessWidget {
  const _ValueGrid({required this.label, required this.values});

  final String label;
  final Map<String, double?> values;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: theme.textTheme.titleSmall),
        const SizedBox(height: 6),
        Row(
          children: [
            for (final entry in values.entries)
              Expanded(
                child: _AxisValue(label: entry.key, value: entry.value),
              ),
          ],
        ),
      ],
    );
  }
}

class _AxisValue extends StatelessWidget {
  const _AxisValue({required this.label, required this.value});

  final String label;
  final double? value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        Text(
          value?.toStringAsFixed(2) ?? '-',
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}
