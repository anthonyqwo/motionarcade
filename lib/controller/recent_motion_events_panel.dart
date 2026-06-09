import 'package:flutter/material.dart';

import 'motion_detector.dart';

class RecentMotionEventsPanel extends StatelessWidget {
  const RecentMotionEventsPanel({super.key, required this.events});

  final List<MotionDetectionResult> events;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Recent Motion Events',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            if (events.isEmpty)
              const Text('No swings detected yet.')
            else
              for (final event in events)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Expanded(child: Text(event.direction.name)),
                      Text('power ${(event.power * 100).round()}%'),
                      const SizedBox(width: 12),
                      Text(event.magnitude.toStringAsFixed(1)),
                    ],
                  ),
                ),
          ],
        ),
      ),
    );
  }
}
