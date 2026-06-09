import 'package:flutter/material.dart';

import '../network/connection_status.dart';
import '../shared/models/fused_motion_sample.dart';
import '../shared/models/sensor_sample.dart';
import 'fused_motion_debug_panel.dart';
import 'haptic_simulator_panel.dart';
import 'motion_detector.dart';
import 'recent_motion_events_panel.dart';
import 'sensor_debug_panel.dart';

class ControllerDebugPage extends StatelessWidget {
  const ControllerDebugPage({
    super.key,
    required this.status,
    required this.lastEvent,
    required this.lastMotion,
    required this.sensorSnapshot,
    required this.fusedMotionSnapshot,
    required this.recentMotionEvents,
    required this.trailTransport,
    required this.udpTrailPacketsPerSecond,
    required this.webSocketTrailPacketsPerSecond,
    required this.trailSamplesPerSecond,
    required this.onSendTestEvent,
  });

  final ConnectionStatus status;
  final String lastEvent;
  final MotionDetectionResult? lastMotion;
  final MotionSensorSnapshot sensorSnapshot;
  final FusedMotionSnapshot fusedMotionSnapshot;
  final List<MotionDetectionResult> recentMotionEvents;
  final String trailTransport;
  final int udpTrailPacketsPerSecond;
  final int webSocketTrailPacketsPerSecond;
  final int trailSamplesPerSecond;
  final VoidCallback? onSendTestEvent;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Controller Debug')),
      body: SafeArea(
        child: ListView(
          key: const ValueKey('controllerDebugList'),
          padding: const EdgeInsets.all(20),
          children: [
            _DebugDiagnosticsCard(
              status: status,
              lastEvent: lastEvent,
              lastMotion: lastMotion,
              trailTransport: trailTransport,
              udpTrailPacketsPerSecond: udpTrailPacketsPerSecond,
              webSocketTrailPacketsPerSecond: webSocketTrailPacketsPerSecond,
              trailSamplesPerSecond: trailSamplesPerSecond,
            ),
            const SizedBox(height: 12),
            FusedMotionDebugPanel(snapshot: fusedMotionSnapshot),
            const SizedBox(height: 12),
            SensorDebugPanel(snapshot: sensorSnapshot),
            const SizedBox(height: 12),
            RecentMotionEventsPanel(events: recentMotionEvents),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              icon: const Icon(Icons.send_outlined),
              label: const Text('Send test event'),
              onPressed: onSendTestEvent,
            ),
            const SizedBox(height: 12),
            const HapticSimulatorPanel(),
          ],
        ),
      ),
    );
  }
}

class _DebugDiagnosticsCard extends StatelessWidget {
  const _DebugDiagnosticsCard({
    required this.status,
    required this.lastEvent,
    required this.lastMotion,
    required this.trailTransport,
    required this.udpTrailPacketsPerSecond,
    required this.webSocketTrailPacketsPerSecond,
    required this.trailSamplesPerSecond,
  });

  final ConnectionStatus status;
  final String lastEvent;
  final MotionDetectionResult? lastMotion;
  final String trailTransport;
  final int udpTrailPacketsPerSecond;
  final int webSocketTrailPacketsPerSecond;
  final int trailSamplesPerSecond;

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
                Icon(Icons.query_stats, color: theme.colorScheme.primary),
                const SizedBox(width: 10),
                Text('Diagnostics', style: theme.textTheme.titleLarge),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _DebugMetric(label: 'Connection', value: status.label),
                _DebugMetric(label: 'Last event', value: lastEvent),
                _DebugMetric(
                  label: 'Direction',
                  value: lastMotion?.direction.name ?? '-',
                ),
                _DebugMetric(
                  label: 'Power',
                  value: lastMotion == null
                      ? '0%'
                      : '${(lastMotion!.power * 100).round()}%',
                ),
                _DebugMetric(label: 'Trail', value: trailTransport),
                _DebugMetric(
                  label: 'Packets/s',
                  value:
                      '${udpTrailPacketsPerSecond + webSocketTrailPacketsPerSecond}',
                ),
                _DebugMetric(
                  label: 'Samples/s',
                  value: '$trailSamplesPerSecond',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DebugMetric extends StatelessWidget {
  const _DebugMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            Text(
              value,
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
