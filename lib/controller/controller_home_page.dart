import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../network/connection_status.dart';
import '../network/room_connection_uri.dart';
import '../network/udp_motion_client_service.dart';
import '../network/websocket_client_service.dart';
import '../shared/models/fused_motion_sample.dart';
import '../shared/models/motion_event.dart';
import '../shared/models/sensor_sample.dart';
import 'calibration_service.dart';
import 'fused_motion_debug_panel.dart';
import 'fused_motion_service.dart';
import 'haptic_feedback_service.dart';
import 'motion_detector.dart';
import 'motion_sensor_service.dart';
import 'motion_trail_streamer.dart';
import '../shared/visual/pulsing_dot.dart';
import 'qr_scan_page.dart';
import 'recent_motion_events_panel.dart';
import 'sensor_debug_panel.dart';
import 'sensitivity_settings.dart';

class ControllerHomePage extends StatefulWidget {
  const ControllerHomePage({
    super.key,
    this.client,
    this.motionSensorService,
    this.fusedMotionService,
  });

  final WebSocketClientService? client;
  final MotionSensorService? motionSensorService;
  final FusedMotionService? fusedMotionService;

  @override
  State<ControllerHomePage> createState() => _ControllerHomePageState();
}

class _ControllerHomePageState extends State<ControllerHomePage> {
  late final WebSocketClientService _client =
      widget.client ?? WebSocketClientService();
  late final UdpMotionClientService _udpClient = UdpMotionClientService();
  late final MotionSensorService _motionSensorService =
      widget.motionSensorService ?? MotionSensorService();
  late final CalibrationService _calibrationService = CalibrationService();
  late final FusedMotionService _fusedMotionService =
      widget.fusedMotionService ??
      FusedMotionService(calibrationService: _calibrationService);
  late MotionDetector _motionDetector = _buildMotionDetector();
  late final MotionTrailStreamer _motionTrailStreamer = MotionTrailStreamer(
    playerId: _playerId,
    onEvent: (event) {
      if (_status == ConnectionStatus.connected) {
        final sampleCount = event.samples.length;
        if (_udpClient.sendTrail(event)) {
          _udpTrailPacketsSent++;
          _trailSamplesSent += sampleCount;
        } else {
          _webSocketTrailPacketsSent++;
          _trailSamplesSent += sampleCount;
          _send(event, updateLastEvent: false);
        }
      }
    },
    calibrationService: _calibrationService,
  );
  final TextEditingController _serverController = TextEditingController();
  final String _playerId = 'p-${DateTime.now().millisecondsSinceEpoch}';

  StreamSubscription<ConnectionStatus>? _statusSubscription;
  StreamSubscription<MotionSensorSnapshot>? _sensorSubscription;
  StreamSubscription<FusedMotionSnapshot>? _fusedMotionSubscription;
  StreamSubscription<MotionEvent>? _clientEventSubscription;
  Timer? _trailRateTimer;
  FeedbackEvent? _lastFeedback;
  bool _showFeedbackOverlay = false;
  Timer? _feedbackOverlayTimer;
  ConnectionStatus _status = ConnectionStatus.idle;
  MotionSensorSnapshot _sensorSnapshot = const MotionSensorSnapshot();
  FusedMotionSnapshot _fusedMotionSnapshot = const FusedMotionSnapshot();
  MotionDetectionResult? _lastMotion;
  final List<MotionDetectionResult> _recentMotionEvents = [];
  SensitivityLevel _sensitivityLevel = SensitivityLevel.medium;
  bool _isCalibrated = false;
  String _lastEvent = 'None';
  String? _errorMessage;
  int _udpTrailPacketsSent = 0;
  int _webSocketTrailPacketsSent = 0;
  int _trailSamplesSent = 0;
  int _lastUdpTrailPacketsSent = 0;
  int _lastWebSocketTrailPacketsSent = 0;
  int _lastTrailSamplesSent = 0;
  int _udpTrailPacketsPerSecond = 0;
  int _webSocketTrailPacketsPerSecond = 0;
  int _trailSamplesPerSecond = 0;

  MotionDetector _buildMotionDetector() {
    return MotionDetector(
      calibrationService: _calibrationService,
      settings: SensitivitySettings.forLevel(_sensitivityLevel),
    );
  }

  @override
  void initState() {
    super.initState();
    _statusSubscription = _client.statusChanges.listen((status) {
      if (mounted) {
        final wasConnected = _status == ConnectionStatus.connected;
        setState(() => _status = status);
        if (wasConnected &&
            (status == ConnectionStatus.disconnected ||
                status == ConnectionStatus.error)) {
          unawaited(_udpClient.disconnect());
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                status == ConnectionStatus.error
                    ? 'Connection error occurred.'
                    : 'Disconnected from room server.',
              ),
              backgroundColor: status == ConnectionStatus.error
                  ? Colors.red
                  : Colors.orange,
            ),
          );
        }
      }
    });
    _sensorSubscription = _motionSensorService.snapshots.listen((snapshot) {
      if (mounted) {
        setState(() => _sensorSnapshot = snapshot);
      }
    });
    _fusedMotionSubscription = _fusedMotionService.snapshots.listen((snapshot) {
      if (mounted) {
        _handleFusedMotionSnapshot(snapshot);
      }
    });
    _trailRateTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _udpTrailPacketsPerSecond =
            _udpTrailPacketsSent - _lastUdpTrailPacketsSent;
        _webSocketTrailPacketsPerSecond =
            _webSocketTrailPacketsSent - _lastWebSocketTrailPacketsSent;
        _trailSamplesPerSecond = _trailSamplesSent - _lastTrailSamplesSent;
        _lastUdpTrailPacketsSent = _udpTrailPacketsSent;
        _lastWebSocketTrailPacketsSent = _webSocketTrailPacketsSent;
        _lastTrailSamplesSent = _trailSamplesSent;
      });
    });
  }

  @override
  void dispose() {
    unawaited(_statusSubscription?.cancel());
    unawaited(_sensorSubscription?.cancel());
    unawaited(_fusedMotionSubscription?.cancel());
    unawaited(_clientEventSubscription?.cancel());
    _trailRateTimer?.cancel();
    _feedbackOverlayTimer?.cancel();
    unawaited(_udpClient.disconnect());
    unawaited(_client.disconnect());
    unawaited(_motionSensorService.dispose());
    unawaited(_fusedMotionService.dispose());
    _serverController.dispose();
    super.dispose();
  }

  Future<void> _connect() async {
    FocusScope.of(context).unfocus();
    final uri = RoomConnectionUri.normalize(_serverController.text);
    if (uri == null) {
      setState(() {
        _errorMessage =
            'Enter a room address like 192.168.1.20:8080 or ws://192.168.1.20:8080.';
      });
      return;
    }

    setState(() {
      _errorMessage = null;
      _status = ConnectionStatus.connecting;
      _serverController.text = uri.toString();
    });

    try {
      await _client.connect(uri);
      if (!mounted) return;

      unawaited(_clientEventSubscription?.cancel());
      _clientEventSubscription = _client.events.listen(_handleIncomingEvent);
      _send(
        JoinEvent(
          playerId: _playerId,
          timestamp: DateTime.now(),
          name: 'Player 1',
          device: 'flutter-controller',
        ),
      );
    } catch (error) {
      if (mounted) {
        setState(() {
          _status = ConnectionStatus.error;
          _errorMessage = error.toString();
        });
      }
    }
  }

  Future<void> _disconnect() async {
    if (!mounted) return;

    setState(() {
      _errorMessage = null;
    });
    unawaited(_clientEventSubscription?.cancel());
    _clientEventSubscription = null;
    unawaited(_udpClient.disconnect());
    _feedbackOverlayTimer?.cancel();
    setState(() {
      _showFeedbackOverlay = false;
    });
    try {
      await _client.disconnect();
    } catch (error) {
      if (mounted) {
        setState(() {
          _errorMessage = error.toString();
        });
      }
    }
  }

  Future<void> _scanQrCode() async {
    final result = await Navigator.of(context).push<String>(
      MaterialPageRoute<String>(builder: (_) => const QrScanPage()),
    );
    if (result == null || !mounted) {
      return;
    }

    setState(() {
      _serverController.text =
          RoomConnectionUri.normalize(result)?.toString() ?? result;
      _errorMessage = null;
    });
  }

  void _sendTestButton() {
    _send(
      ButtonEvent(
        playerId: _playerId,
        timestamp: DateTime.now(),
        button: 'test',
      ),
    );
  }

  void _calibrateGrip() {
    final fusedSample = _fusedMotionSnapshot.sample;
    final neutral = fusedSample == null
        ? _calibrationService.calibrate(_sensorSnapshot)
        : _calibrationService.calibrateFusedMotion(fusedSample);
    if (neutral == null) {
      setState(() => _errorMessage = 'Start motion before calibrating.');
      return;
    }

    _send(
      CalibrateEvent(
        playerId: _playerId,
        timestamp: DateTime.now(),
        neutral: neutral,
      ),
    );
    setState(() {
      _isCalibrated = true;
      _errorMessage = null;
    });
  }

  void _handleFusedMotionSnapshot(FusedMotionSnapshot snapshot) {
    final trailSample = snapshot.controllerSample;
    if (trailSample != null && snapshot.isActive) {
      _motionTrailStreamer.onSample(trailSample);
    }

    final result = _motionDetector.detectFused(snapshot);

    setState(() {
      _fusedMotionSnapshot = snapshot;
      if (result != null) {
        _lastMotion = result;
        _recentMotionEvents.insert(0, result);
        if (_recentMotionEvents.length > 10) {
          _recentMotionEvents.removeLast();
        }
      }
    });

    if (result != null) {
      unawaited(HapticFeedbackService.trigger(HapticPattern.medium));
      if (_status == ConnectionStatus.connected) {
        _send(result.toSlashEvent(playerId: _playerId));
      }
    }
  }

  void _handleIncomingEvent(MotionEvent event) {
    if (event is FeedbackEvent) {
      unawaited(HapticFeedbackService.trigger(event.haptic));
      if (!mounted) return;

      setState(() {
        _lastFeedback = event;
        _showFeedbackOverlay = true;
      });
      _feedbackOverlayTimer?.cancel();
      _feedbackOverlayTimer = Timer(const Duration(milliseconds: 1500), () {
        if (mounted) {
          setState(() {
            _showFeedbackOverlay = false;
          });
        }
      });
    } else if (event is TransportConfigEvent) {
      unawaited(_connectUdpTransport(event));
    }
  }

  Future<void> _connectUdpTransport(TransportConfigEvent event) async {
    if (event.udpHost.isEmpty ||
        event.udpPort <= 0 ||
        event.roomToken.isEmpty) {
      return;
    }
    try {
      await _udpClient.connect(
        host: event.udpHost,
        port: event.udpPort,
        roomToken: event.roomToken,
      );
    } catch (_) {
      // Keep WebSocket trail fallback active when UDP is unavailable.
    }
  }

  void _send(MotionEvent event, {bool updateLastEvent = true}) {
    try {
      _client.send(event);
      if (updateLastEvent && mounted) {
        setState(() => _lastEvent = event.type);
      }
    } catch (error) {
      if (!mounted) return;
      setState(() => _errorMessage = error.toString());
    }
  }

  void _toggleSensors() {
    if (_isMotionActive) {
      unawaited(_motionSensorService.stop());
      unawaited(_fusedMotionService.stop());
      _motionTrailStreamer.reset();
    } else {
      _motionSensorService.start();
      _fusedMotionService.start();
    }
  }

  bool get _isMotionActive {
    return _sensorSnapshot.isActive || _fusedMotionSnapshot.isActive;
  }

  void _setSensitivity(SensitivityLevel level) {
    if (_sensitivityLevel == level) {
      return;
    }

    setState(() {
      _sensitivityLevel = level;
      _motionDetector = _buildMotionDetector();
    });
    unawaited(HapticFeedback.selectionClick());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isConnected = _status == ConnectionStatus.connected;
    final feedback = _lastFeedback;

    return Scaffold(
      appBar: AppBar(title: const Text('Motion Controller')),
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  Text(
                    'Phone Controller',
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Connect to a room, calibrate your grip, then send motion events.',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 24),
                  TextField(
                    controller: _serverController,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      labelText: 'Server URI',
                      hintText: '192.168.1.20:8080',
                      prefixIcon: Icon(Icons.link),
                    ),
                    keyboardType: TextInputType.url,
                    textInputAction: TextInputAction.go,
                    onSubmitted: (_) {
                      if (_status != ConnectionStatus.connecting &&
                          _status != ConnectionStatus.connected) {
                        unawaited(_connect());
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.qr_code_scanner),
                    label: const Text('Scan room QR'),
                    onPressed: _scanQrCode,
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    icon: Icon(
                      _status == ConnectionStatus.connecting
                          ? Icons.sync
                          : _status == ConnectionStatus.connected
                          ? Icons.power_off
                          : Icons.power_settings_new,
                    ),
                    label: Text(
                      _status == ConnectionStatus.connecting
                          ? 'Connecting...'
                          : _status == ConnectionStatus.connected
                          ? 'Disconnect'
                          : 'Connect',
                    ),
                    onPressed: _status == ConnectionStatus.connecting
                        ? null
                        : _status == ConnectionStatus.connected
                        ? _disconnect
                        : _connect,
                    style: _status == ConnectionStatus.connected
                        ? FilledButton.styleFrom(
                            backgroundColor: theme.colorScheme.error,
                            foregroundColor: theme.colorScheme.onError,
                          )
                        : null,
                  ),
                  if (_errorMessage != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _errorMessage!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.error,
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  _ControllerStatusGrid(
                    status: _status,
                    lastEvent: _lastEvent,
                    lastMotion: _lastMotion,
                    isMotionActive: _isMotionActive,
                    trailTransport: _udpClient.isConnected
                        ? 'UDP'
                        : 'WebSocket',
                    udpTrailPacketsPerSecond: _udpTrailPacketsPerSecond,
                    webSocketTrailPacketsPerSecond:
                        _webSocketTrailPacketsPerSecond,
                    trailSamplesPerSecond: _trailSamplesPerSecond,
                  ),
                  const SizedBox(height: 24),
                  FusedMotionDebugPanel(snapshot: _fusedMotionSnapshot),
                  const SizedBox(height: 12),
                  SensorDebugPanel(snapshot: _sensorSnapshot),
                  const SizedBox(height: 12),
                  FilledButton.tonalIcon(
                    icon: Icon(
                      _isMotionActive ? Icons.sensors_off : Icons.sensors,
                    ),
                    label: Text(
                      _isMotionActive ? 'Stop motion' : 'Start motion',
                    ),
                    onPressed: _toggleSensors,
                  ),
                  const SizedBox(height: 24),
                  _SensitivityControl(
                    level: _sensitivityLevel,
                    settings: SensitivitySettings.forLevel(_sensitivityLevel),
                    onChanged: _setSensitivity,
                  ),
                  const SizedBox(height: 24),
                  RecentMotionEventsPanel(events: _recentMotionEvents),
                  const SizedBox(height: 24),
                  _CalibrationStatusCard(isCalibrated: _isCalibrated),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.send_outlined),
                    label: const Text('Send test event'),
                    onPressed: isConnected ? _sendTestButton : null,
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.center_focus_strong),
                    label: const Text('Calibrate grip'),
                    onPressed: _calibrateGrip,
                  ),
                  const SizedBox(height: 24),
                  const _HapticSimulatorPanel(),
                ],
              ),
            ),
            if (_showFeedbackOverlay && feedback != null)
              Positioned(
                left: 20,
                right: 20,
                top: 10,
                child: _FeedbackOverlayBanner(event: feedback),
              ),
          ],
        ),
      ),
    );
  }
}

class _CalibrationStatusCard extends StatelessWidget {
  const _CalibrationStatusCard({required this.isCalibrated});

  final bool isCalibrated;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Icon(
              isCalibrated ? Icons.check_circle : Icons.center_focus_strong,
              color: isCalibrated
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                isCalibrated ? 'Grip calibrated' : 'Grip not calibrated',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SensitivityControl extends StatelessWidget {
  const _SensitivityControl({
    required this.level,
    required this.settings,
    required this.onChanged,
  });

  final SensitivityLevel level;
  final SensitivitySettings settings;
  final ValueChanged<SensitivityLevel> onChanged;

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
                Icon(Icons.tune, color: theme.colorScheme.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Sensitivity',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            SegmentedButton<SensitivityLevel>(
              segments: const [
                ButtonSegment(
                  value: SensitivityLevel.low,
                  icon: Icon(Icons.remove),
                  label: Text('Low'),
                ),
                ButtonSegment(
                  value: SensitivityLevel.medium,
                  icon: Icon(Icons.drag_handle),
                  label: Text('Med'),
                ),
                ButtonSegment(
                  value: SensitivityLevel.high,
                  icon: Icon(Icons.add),
                  label: Text('High'),
                ),
              ],
              selected: {level},
              onSelectionChanged: (selection) {
                onChanged(selection.first);
              },
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                _SensitivityMetric(
                  label: 'Swing',
                  value: settings.swingThreshold.toStringAsFixed(1),
                ),
                _SensitivityMetric(
                  label: 'Forward',
                  value: settings.forwardBackwardThreshold.toStringAsFixed(1),
                ),
                _SensitivityMetric(
                  label: 'Cooldown',
                  value: '${settings.cooldown.inMilliseconds}ms',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SensitivityMetric extends StatelessWidget {
  const _SensitivityMetric({required this.label, required this.value});

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

class _ControllerStatusGrid extends StatelessWidget {
  const _ControllerStatusGrid({
    required this.status,
    required this.lastEvent,
    required this.lastMotion,
    required this.isMotionActive,
    required this.trailTransport,
    required this.udpTrailPacketsPerSecond,
    required this.webSocketTrailPacketsPerSecond,
    required this.trailSamplesPerSecond,
  });

  final ConnectionStatus status;
  final String lastEvent;
  final MotionDetectionResult? lastMotion;
  final bool isMotionActive;
  final String trailTransport;
  final int udpTrailPacketsPerSecond;
  final int webSocketTrailPacketsPerSecond;
  final int trailSamplesPerSecond;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 560;

        final cards = [
          _StatusCard(
            icon: status == ConnectionStatus.connected
                ? Icons.wifi
                : Icons.wifi_off,
            label: 'Connection',
            value: status.label,
            trailing: status == ConnectionStatus.connected
                ? const PulsingDot(color: Colors.green, size: 8)
                : status == ConnectionStatus.connecting
                ? const PulsingDot(color: Colors.blue, size: 8)
                : null,
          ),
          _StatusCard(
            icon: Icons.sensors,
            label: 'Motion',
            value: isMotionActive ? 'Active' : 'Idle',
            trailing: isMotionActive
                ? const PulsingDot(color: Colors.red, size: 8)
                : null,
          ),
          _StatusCard(
            icon: Icons.explore_outlined,
            label: 'Direction',
            value: lastMotion?.direction.name ?? '-',
          ),
          _StatusCard(
            icon: Icons.speed,
            label: 'Power',
            value: lastMotion == null
                ? '0%'
                : '${(lastMotion!.power * 100).round()}%',
          ),
          _StatusCard(
            icon: Icons.send_outlined,
            label: 'Last event',
            value: lastEvent,
          ),
          _StatusCard(
            icon: Icons.timeline,
            label: 'Trail',
            value:
                '$trailTransport ${udpTrailPacketsPerSecond + webSocketTrailPacketsPerSecond}p/s ${trailSamplesPerSecond}s/s',
            trailing: trailTransport == 'UDP'
                ? const PulsingDot(color: Colors.green, size: 8)
                : null,
          ),
        ];

        if (isWide) {
          return Row(
            children: [
              for (final card in cards)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: card,
                  ),
                ),
            ],
          );
        }

        return Column(
          children: [
            for (final card in cards)
              Padding(padding: const EdgeInsets.only(bottom: 8), child: card),
          ],
        );
      },
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({
    required this.icon,
    required this.label,
    required this.value,
    this.trailing,
  });

  final IconData icon;
  final String label;
  final String value;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Icon(icon, color: theme.colorScheme.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: theme.textTheme.labelLarge),
                  Text(
                    value,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            if (trailing != null) ...[const SizedBox(width: 8), trailing!],
          ],
        ),
      ),
    );
  }
}

class _FeedbackOverlayBanner extends StatelessWidget {
  const _FeedbackOverlayBanner({required this.event});

  final FeedbackEvent event;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final (color, label) = switch (event.result) {
      FeedbackResult.perfect => (Colors.green, 'PERFECT!'),
      FeedbackResult.good => (Colors.cyan, 'GOOD'),
      FeedbackResult.weak => (Colors.yellow, 'WEAK'),
      FeedbackResult.miss => (Colors.red, 'MISS'),
    };

    return Card(
      color: color.withValues(alpha: 0.9),
      elevation: 6,
      shadowColor: color.withValues(alpha: 0.5),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: color, width: 2),
      ),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: theme.textTheme.headlineLarge?.copyWith(
                color: event.result == FeedbackResult.weak
                    ? Colors.black
                    : Colors.white,
                fontWeight: FontWeight.w900,
                letterSpacing: 2,
                shadows: [
                  Shadow(
                    color: Colors.black.withValues(alpha: 0.5),
                    offset: const Offset(1, 2),
                    blurRadius: 4,
                  ),
                ],
              ),
            ),
            if (event.message != null) ...[
              const SizedBox(height: 4),
              Text(
                event.message!,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: event.result == FeedbackResult.weak
                      ? Colors.black87
                      : Colors.white70,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _HapticSimulatorPanel extends StatefulWidget {
  const _HapticSimulatorPanel();

  @override
  State<_HapticSimulatorPanel> createState() => _HapticSimulatorPanelState();
}

class _HapticSimulatorPanelState extends State<_HapticSimulatorPanel>
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
