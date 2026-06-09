import 'package:flutter/material.dart';

import '../shared/models/sensor_sample.dart';

class SensorDebugPanel extends StatelessWidget {
  const SensorDebugPanel({super.key, required this.snapshot});

  final MotionSensorSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  snapshot.isActive ? Icons.sensors : Icons.sensors_off,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Sensor Debug',
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
            _SampleRows(label: 'Accelerometer', sample: snapshot.accelerometer),
            const SizedBox(height: 10),
            _SampleRows(label: 'Gyroscope', sample: snapshot.gyroscope),
            const Divider(height: 24),
            Row(
              children: [
                const Expanded(child: Text('Motion magnitude')),
                Text(
                  snapshot.motionMagnitude.toStringAsFixed(2),
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

class _SampleRows extends StatelessWidget {
  const _SampleRows({required this.label, required this.sample});

  final String label;
  final SensorSample? sample;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final value = sample;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: theme.textTheme.titleSmall),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: _AxisValue(label: 'x', value: value?.x),
            ),
            Expanded(
              child: _AxisValue(label: 'y', value: value?.y),
            ),
            Expanded(
              child: _AxisValue(label: 'z', value: value?.z),
            ),
            Expanded(
              child: _AxisValue(label: 'mag', value: value?.magnitude),
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
            fontFeatures: const [],
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}
