import 'dart:async';

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
import 'fused_motion_service.dart';
import 'haptic_feedback_service.dart';
import 'motion_detector.dart';
import 'motion_window_buffer.dart';
import 'motion_sensor_service.dart';
import 'motion_trail_streamer.dart';
import 'controller_debug_page.dart';
import 'qr_scan_page.dart';
import 'sensitivity_settings.dart';
import 'shoot_detector.dart';

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
  final MotionWindowBuffer _shotMotionBuffer = MotionWindowBuffer(
    capacity: 140,
  );
  final ShootDetector _shootDetector = const ShootDetector(
    minHoldDurationMs: 0,
  );
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
  RoomStateEvent? _roomState;
  SensitivityLevel _sensitivityLevel = SensitivityLevel.medium;
  bool _isCalibrated = false;
  String? _calibrationMessage;
  int _calibrationCount = 0;
  String _lastEvent = 'None';
  String _lastShotStatus = 'Ready';
  String? _errorMessage;
  ShootEvent? _lastShotEvent;
  DateTime? _shotHoldStartedAt;
  bool _isShotHolding = false;
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
      const message = 'Start motion before calibrating.';
      setState(() {
        _errorMessage = message;
        _calibrationMessage = message;
      });
      return;
    }

    final wasCalibrated = _isCalibrated;
    _send(
      CalibrateEvent(
        playerId: _playerId,
        timestamp: DateTime.now(),
        neutral: neutral,
      ),
    );
    setState(() {
      _isCalibrated = true;
      _calibrationCount++;
      _calibrationMessage = wasCalibrated
          ? 'Calibration updated ($_calibrationCount)'
          : 'Calibration saved';
      _errorMessage = null;
    });
    unawaited(HapticFeedback.mediumImpact());
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(wasCalibrated ? 'Calibration updated.' : 'Calibrated.'),
        duration: const Duration(milliseconds: 900),
      ),
    );
  }

  void _handleFusedMotionSnapshot(FusedMotionSnapshot snapshot) {
    final trailSample = snapshot.controllerSample;
    if (trailSample != null && snapshot.isActive) {
      _motionTrailStreamer.onSample(trailSample);
      _shotMotionBuffer.add(trailSample);
    }

    final shouldDetectSlash =
        (_roomState?.selectedGame ?? GameId.motionSaber) != GameId.basketball;
    final result = shouldDetectSlash
        ? _motionDetector.detectFused(snapshot)
        : null;

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
    } else if (event is RoomStateEvent) {
      if (!mounted) return;
      setState(() {
        _roomState = event;
      });
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

  void _sendGameCommand(GameCommand command, {GameId? gameId}) {
    if (_status != ConnectionStatus.connected) {
      setState(() => _errorMessage = 'Connect to a room first.');
      return;
    }

    _send(
      GameCommandEvent(
        playerId: _playerId,
        timestamp: DateTime.now(),
        command: command,
        gameId: gameId,
        requestId: DateTime.now().microsecondsSinceEpoch.toRadixString(36),
      ),
    );
  }

  void _startShotHold() {
    if (_isShotHolding) {
      return;
    }
    if (_status != ConnectionStatus.connected) {
      setState(() => _errorMessage = 'Connect to a room first.');
      return;
    }
    if (!_isMotionActive) {
      _motionSensorService.start();
      _fusedMotionService.start();
    }

    final now = DateTime.now();
    setState(() {
      _isShotHolding = true;
      _shotHoldStartedAt = now;
      _lastShotStatus = _isMotionActive
          ? 'Release to shoot'
          : 'Starting motion';
      _errorMessage = null;
    });
    _send(
      ShootHoldEvent(playerId: _playerId, timestamp: now, pressed: true),
      updateLastEvent: false,
    );
    unawaited(HapticFeedback.selectionClick());
  }

  void _releaseShotHold({bool cancelled = false}) {
    final startedAt = _shotHoldStartedAt;
    if (!_isShotHolding || startedAt == null) {
      return;
    }

    final now = DateTime.now();
    final holdDurationMs = now.difference(startedAt).inMilliseconds;
    _send(
      ShootHoldEvent(playerId: _playerId, timestamp: now, pressed: false),
      updateLastEvent: false,
    );

    if (cancelled) {
      setState(() {
        _isShotHolding = false;
        _shotHoldStartedAt = null;
        _lastShotStatus = 'Cancelled';
      });
      return;
    }

    final samples = _shotMotionBuffer.getWindowSnapshot(900);
    final detection = _shootDetector.detect(
      samples: samples,
      holdDurationMs: holdDurationMs,
      playerId: _playerId,
      timestamp: now,
    );
    final event = detection.event;
    if (event == null) {
      setState(() {
        _isShotHolding = false;
        _shotHoldStartedAt = null;
        _lastShotStatus = detection.reason;
      });
      unawaited(HapticFeedback.lightImpact());
      return;
    }

    _send(event);
    setState(() {
      _isShotHolding = false;
      _shotHoldStartedAt = null;
      _lastShotEvent = event;
      _lastShotStatus = 'Shot sent';
    });
    unawaited(HapticFeedback.mediumImpact());
  }

  void _openDebugPage() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ControllerDebugPage(
          status: _status,
          lastEvent: _lastEvent,
          lastMotion: _lastMotion,
          sensorSnapshot: _sensorSnapshot,
          fusedMotionSnapshot: _fusedMotionSnapshot,
          recentMotionEvents: List<MotionDetectionResult>.from(
            _recentMotionEvents,
          ),
          trailTransport: _udpClient.isConnected ? 'UDP' : 'WebSocket',
          udpTrailPacketsPerSecond: _udpTrailPacketsPerSecond,
          webSocketTrailPacketsPerSecond: _webSocketTrailPacketsPerSecond,
          trailSamplesPerSecond: _trailSamplesPerSecond,
          onSendTestEvent: _status == ConnectionStatus.connected
              ? _sendTestButton
              : null,
        ),
      ),
    );
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

  bool get _isBasketballSelected {
    return (_roomState?.selectedGame ?? GameId.motionSaber) ==
        GameId.basketball;
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
                key: const ValueKey('controllerHomeList'),
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
                  _RoomStatusCard(status: _status, roomState: _roomState),
                  const SizedBox(height: 12),
                  _GameControlsCard(
                    roomState: _roomState,
                    isConnected: isConnected,
                    onSelectGame: (gameId) => _sendGameCommand(
                      GameCommand.selectGame,
                      gameId: gameId,
                    ),
                    onStart: () => _sendGameCommand(
                      GameCommand.startGame,
                      gameId: _roomState?.selectedGame ?? GameId.motionSaber,
                    ),
                    onRestart: () => _sendGameCommand(
                      GameCommand.restartGame,
                      gameId: _roomState?.selectedGame ?? GameId.motionSaber,
                    ),
                    onBackToRoom: () => _sendGameCommand(
                      GameCommand.backToRoom,
                      gameId: _roomState?.selectedGame ?? GameId.motionSaber,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _PlayerScoreCard(roomState: _roomState, playerId: _playerId),
                  if (_isBasketballSelected) ...[
                    const SizedBox(height: 12),
                    _BasketballShotPad(
                      isEnabled: isConnected,
                      isHolding: _isShotHolding,
                      lastStatus: _lastShotStatus,
                      lastShot: _lastShotEvent,
                      score: _roomState?.scoreForPlayer(_playerId),
                      onHoldStart: _startShotHold,
                      onHoldEnd: () => _releaseShotHold(),
                      onHoldCancel: () => _releaseShotHold(cancelled: true),
                    ),
                  ],
                  const SizedBox(height: 12),
                  _MotionReadinessCard(
                    isMotionActive: _isMotionActive,
                    isCalibrated: _isCalibrated,
                    calibrationMessage: _calibrationMessage,
                    level: _sensitivityLevel,
                    settings: SensitivitySettings.forLevel(_sensitivityLevel),
                    onChanged: _setSensitivity,
                    onToggleSensors: _toggleSensors,
                    onCalibrateGrip: _calibrateGrip,
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.bug_report_outlined),
                    label: const Text('Open debug panel'),
                    onPressed: _openDebugPage,
                  ),
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

String _gameLabel(GameId gameId) {
  return switch (gameId) {
    GameId.motionSaber => 'Motion Saber',
    GameId.basketball => 'Basketball',
    GameId.pingPong => 'Ping Pong',
  };
}

String _shortGameLabel(GameId gameId) {
  return switch (gameId) {
    GameId.motionSaber => 'Saber',
    GameId.basketball => 'Basket',
    GameId.pingPong => 'Pong',
  };
}

IconData _gameIcon(GameId gameId) {
  return switch (gameId) {
    GameId.motionSaber => Icons.flash_on,
    GameId.basketball => Icons.sports_basketball,
    GameId.pingPong => Icons.sports_tennis,
  };
}

String _phaseLabel(RoomPhase? phase) {
  return switch (phase) {
    RoomPhase.lobby => 'Lobby',
    RoomPhase.countdown => 'Countdown',
    RoomPhase.playing => 'Playing',
    RoomPhase.gameOver => 'Game Over',
    null => 'Not joined',
  };
}

String _formatDuration(double seconds) {
  final wholeSeconds = seconds.floor();
  final minutes = wholeSeconds ~/ 60;
  final remainingSeconds = wholeSeconds % 60;
  return '$minutes:${remainingSeconds.toString().padLeft(2, '0')}';
}

class _MetricChip extends StatelessWidget {
  const _MetricChip({required this.label, required this.value});

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

class _RoomStatusCard extends StatelessWidget {
  const _RoomStatusCard({required this.status, required this.roomState});

  final ConnectionStatus status;
  final RoomStateEvent? roomState;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state = roomState;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.meeting_room, color: theme.colorScheme.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Room',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Text(_phaseLabel(state?.roomPhase)),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _MetricChip(label: 'Connection', value: status.label),
                _MetricChip(
                  label: 'Game',
                  value: _gameLabel(state?.selectedGame ?? GameId.motionSaber),
                ),
                _MetricChip(
                  label: 'Players',
                  value: '${state?.connectedPlayers ?? 0}',
                ),
                _MetricChip(
                  label: 'Lives',
                  value: state == null || state.maxSharedLives == 0
                      ? '-'
                      : '${state.sharedLives}/${state.maxSharedLives}',
                ),
              ],
            ),
            if (state?.message != null) ...[
              const SizedBox(height: 10),
              Text(
                state!.message!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _GameControlsCard extends StatelessWidget {
  const _GameControlsCard({
    required this.roomState,
    required this.isConnected,
    required this.onSelectGame,
    required this.onStart,
    required this.onRestart,
    required this.onBackToRoom,
  });

  final RoomStateEvent? roomState;
  final bool isConnected;
  final ValueChanged<GameId> onSelectGame;
  final VoidCallback onStart;
  final VoidCallback onRestart;
  final VoidCallback onBackToRoom;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state = roomState;
    final selectedGame = state?.selectedGame ?? GameId.motionSaber;
    final availableGames = state?.availableGames ?? GameId.values;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.sports_esports, color: theme.colorScheme.primary),
                const SizedBox(width: 10),
                Text('Game Control', style: theme.textTheme.titleLarge),
              ],
            ),
            const SizedBox(height: 14),
            SegmentedButton<GameId>(
              segments: [
                for (final gameId in availableGames)
                  ButtonSegment(
                    value: gameId,
                    icon: Icon(_gameIcon(gameId)),
                    label: Text(_shortGameLabel(gameId)),
                  ),
              ],
              selected: {selectedGame},
              onSelectionChanged: !isConnected
                  ? null
                  : (selection) => onSelectGame(selection.first),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('Start'),
                    onPressed: isConnected && (state?.canStart ?? false)
                        ? onStart
                        : null,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.tonalIcon(
                    icon: const Icon(Icons.replay),
                    label: const Text('Restart'),
                    onPressed: isConnected && (state?.canRestart ?? false)
                        ? onRestart
                        : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              icon: const Icon(Icons.meeting_room_outlined),
              label: const Text('Back to room'),
              onPressed: isConnected && (state?.canBackToRoom ?? false)
                  ? onBackToRoom
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}

class _PlayerScoreCard extends StatelessWidget {
  const _PlayerScoreCard({required this.roomState, required this.playerId});

  final RoomStateEvent? roomState;
  final String playerId;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state = roomState;
    final score = state?.scoreForPlayer(playerId);
    final leaders = state?.playerScores.take(3).toList() ?? const [];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.emoji_events, color: theme.colorScheme.primary),
                const SizedBox(width: 10),
                Text('Score', style: theme.textTheme.titleLarge),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _MetricChip(label: 'Score', value: '${score?.score ?? 0}'),
                _MetricChip(label: 'Combo', value: '${score?.combo ?? 0}'),
                _MetricChip(label: 'Max', value: '${score?.maxCombo ?? 0}'),
                _MetricChip(
                  label: 'Hit/Miss',
                  value: '${score?.hits ?? 0}/${score?.misses ?? 0}',
                ),
                _MetricChip(
                  label: 'Time',
                  value: _formatDuration(state?.survivedSeconds ?? 0),
                ),
              ],
            ),
            if (leaders.isNotEmpty) ...[
              const Divider(height: 24),
              for (final leader in leaders)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 26,
                        child: Text(
                          '#${leader.rank}',
                          style: theme.textTheme.labelLarge,
                        ),
                      ),
                      Expanded(
                        child: Text(
                          leader.name,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: leader.playerId == playerId
                                ? FontWeight.w800
                                : FontWeight.w500,
                          ),
                        ),
                      ),
                      Text(
                        '${leader.score}',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _BasketballShotPad extends StatelessWidget {
  const _BasketballShotPad({
    required this.isEnabled,
    required this.isHolding,
    required this.lastStatus,
    required this.lastShot,
    required this.score,
    required this.onHoldStart,
    required this.onHoldEnd,
    required this.onHoldCancel,
  });

  final bool isEnabled;
  final bool isHolding;
  final String lastStatus;
  final ShootEvent? lastShot;
  final PlayerScoreSnapshot? score;
  final VoidCallback onHoldStart;
  final VoidCallback onHoldEnd;
  final VoidCallback onHoldCancel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final activeColor = isHolding
        ? const Color(0xFFF97316)
        : theme.colorScheme.primary;
    final foreground = isEnabled
        ? theme.colorScheme.onPrimary
        : theme.colorScheme.onSurfaceVariant;

    return Card(
      color: isEnabled
          ? activeColor.withValues(alpha: isHolding ? 0.95 : 0.82)
          : theme.colorScheme.surfaceContainerHighest,
      child: Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: isEnabled ? (_) => onHoldStart() : null,
        onPointerUp: isEnabled ? (_) => onHoldEnd() : null,
        onPointerCancel: isEnabled ? (_) => onHoldCancel() : null,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 188),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Icon(Icons.sports_basketball, color: foreground),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Basketball Shot',
                        style: theme.textTheme.titleLarge?.copyWith(
                          color: foreground,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    Text(
                      '${score?.score ?? 0} pts  ${score?.combo ?? 0}x',
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: foreground.withValues(alpha: 0.86),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                Center(
                  child: Text(
                    isHolding ? 'RELEASE' : 'SHOOT',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      color: foreground,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.0,
                    ),
                  ),
                ),
                const SizedBox(height: 28),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        lastStatus,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: foreground.withValues(alpha: 0.88),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    if (lastShot != null)
                      Text(
                        'P ${lastShot!.power.toStringAsFixed(2)}  A ${lastShot!.angle.round()}',
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: foreground.withValues(alpha: 0.82),
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MotionReadinessCard extends StatelessWidget {
  const _MotionReadinessCard({
    required this.isMotionActive,
    required this.isCalibrated,
    required this.calibrationMessage,
    required this.level,
    required this.settings,
    required this.onChanged,
    required this.onToggleSensors,
    required this.onCalibrateGrip,
  });

  final bool isMotionActive;
  final bool isCalibrated;
  final String? calibrationMessage;
  final SensitivityLevel level;
  final SensitivitySettings settings;
  final ValueChanged<SensitivityLevel> onChanged;
  final VoidCallback onToggleSensors;
  final VoidCallback onCalibrateGrip;

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
                  isMotionActive ? Icons.sensors : Icons.sensors_off,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Motion Readiness',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Text(isCalibrated ? 'Calibrated' : 'Not calibrated'),
              ],
            ),
            if (calibrationMessage != null) ...[
              const SizedBox(height: 8),
              Text(
                calibrationMessage!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: FilledButton.tonalIcon(
                    icon: Icon(
                      isMotionActive ? Icons.sensors_off : Icons.sensors,
                    ),
                    label: Text(
                      isMotionActive ? 'Stop motion' : 'Start motion',
                    ),
                    onPressed: onToggleSensors,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.center_focus_strong),
                    label: const Text('Calibrate'),
                    onPressed: onCalibrateGrip,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _SensitivityControl(
              level: level,
              settings: settings,
              onChanged: onChanged,
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
