import 'dart:async';

import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../network/connection_status.dart';
import '../network/motion_event_dispatcher.dart';
import '../network/room_host_info.dart';
import '../network/udp_motion_server_service.dart';
import '../network/websocket_server_service.dart';
import '../shared/models/motion_event.dart';
import '../shared/models/player.dart';
import '../shared/visual/trail_point_buffer.dart';
import '../shared/visual/pulsing_dot.dart';
import '../shared/visual/trail_renderer.dart';
import 'game_shell_page.dart';
import '../games/saber/saber_game_page.dart';

class RoomPage extends StatefulWidget {
  const RoomPage({super.key, this.server});

  final WebSocketServerService? server;

  @override
  State<RoomPage> createState() => _RoomPageState();
}

class _RoomPageState extends State<RoomPage> {
  late final WebSocketServerService _server =
      widget.server ?? WebSocketServerService();
  final String _roomToken = DateTime.now().microsecondsSinceEpoch.toRadixString(
    36,
  );
  late final UdpMotionServerService _udpServer = UdpMotionServerService(
    roomToken: _roomToken,
  );

  final List<Player> _players = [];
  final List<String> _eventLog = [];
  final TrailPointBuffer _trailBuffer = TrailPointBuffer();

  StreamSubscription<MotionEvent>? _eventSubscription;
  StreamSubscription<MotionEvent>? _udpEventSubscription;
  StreamSubscription<ConnectionStatus>? _statusSubscription;
  RoomHostInfo? _host;
  ConnectionStatus _status = ConnectionStatus.starting;
  SlashEvent? _lastSlash;
  String? _errorMessage;
  int _udpTrailPacketsReceived = 0;
  int _webSocketTrailPacketsReceived = 0;

  MotionDirection _targetDirection = MotionDirection.up;
  Timer? _targetDirectionTimer;
  Timer? _trailPruneTimer;

  @override
  void initState() {
    super.initState();
    _statusSubscription = _server.statusChanges.listen((status) {
      if (mounted) {
        setState(() => _status = status);
      }
    });
    _eventSubscription = _server.events.listen((event) {
      _trackTrailPacket(event, isUdp: false);
      _handleEvent(event);
    });
    _udpEventSubscription = _udpServer.events.listen((event) {
      _trackTrailPacket(event, isUdp: true);
      _handleEvent(event);
    });
    unawaited(_startServer());

    _targetDirectionTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (mounted) {
        setState(() {
          final nextIndex =
              (MotionDirection.values.indexOf(_targetDirection) + 1) %
              MotionDirection.values.length;
          _targetDirection = MotionDirection.values[nextIndex];
        });
      }
    });
    _trailPruneTimer = Timer.periodic(const Duration(milliseconds: 250), (_) {
      _trailBuffer.prune(DateTime.now());
    });
  }

  @override
  void dispose() {
    _targetDirectionTimer?.cancel();
    _trailPruneTimer?.cancel();
    unawaited(_eventSubscription?.cancel());
    unawaited(_udpEventSubscription?.cancel());
    unawaited(_statusSubscription?.cancel());
    unawaited(_server.stop());
    unawaited(_udpServer.stop());
    super.dispose();
  }

  Future<void> _startServer() async {
    try {
      final websocketHost = await _server.start();
      final udpPort = await _udpServer.start();
      final host = RoomHostInfo(
        ipAddress: websocketHost.ipAddress,
        port: websocketHost.port,
        udpPort: udpPort,
      );
      if (mounted) {
        setState(() {
          _host = host;
          _errorMessage = null;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _status = ConnectionStatus.error;
          _errorMessage = error.toString();
        });
      }
    }
  }

  void _handleEvent(MotionEvent event) {
    final dispatcher = MotionEventDispatcher(
      onJoin: _handleJoin,
      onDisconnect: _handleDisconnect,
      onSlash: _handleSlash,
      onMotionTrail: _handleMotionTrail,
    );

    if (event is MotionTrailEvent) {
      dispatcher.dispatch(event);
    } else {
      setState(() {
        dispatcher.dispatch(event);
        _eventLog.insert(0, '${event.type} from ${event.playerId}');
        if (_eventLog.length > 8) {
          _eventLog.removeLast();
        }
      });
    }
  }

  void _trackTrailPacket(MotionEvent event, {required bool isUdp}) {
    if (event is! MotionTrailEvent) {
      return;
    }
    if (isUdp) {
      _udpTrailPacketsReceived++;
    } else {
      _webSocketTrailPacketsReceived++;
    }
  }

  void _handleJoin(JoinEvent event) {
    final existingIndex = _players.indexWhere(
      (player) => player.id == event.playerId,
    );
    final player = Player(
      id: event.playerId,
      name: event.name,
      deviceLabel: event.device,
      status: PlayerConnectionStatus.connected,
    );
    if (existingIndex == -1) {
      _players.add(player);
    } else {
      _players[existingIndex] = player;
    }
    _sendTransportConfig(event.playerId);
  }

  void _sendTransportConfig(String playerId) {
    final host = _host;
    final udpPort = host?.udpPort;
    if (host == null || udpPort == null) {
      return;
    }
    _server.sendToPlayer(
      playerId,
      TransportConfigEvent(
        playerId: playerId,
        timestamp: DateTime.now(),
        udpHost: host.ipAddress,
        udpPort: udpPort,
        roomToken: _roomToken,
      ),
    );
  }

  void _handleDisconnect(DisconnectEvent event) {
    final existingIndex = _players.indexWhere(
      (player) => player.id == event.playerId,
    );
    if (existingIndex != -1) {
      final existingPlayer = _players[existingIndex];
      final updatedPlayer = Player(
        id: existingPlayer.id,
        name: existingPlayer.name,
        deviceLabel: existingPlayer.deviceLabel,
        status: PlayerConnectionStatus.disconnected,
      );
      _players[existingIndex] = updatedPlayer;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${existingPlayer.name} has disconnected.'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  void _startGame() {
    _eventSubscription?.cancel();
    _udpEventSubscription?.cancel();
    _eventSubscription = null;
    _udpEventSubscription = null;

    Navigator.of(context)
        .push(
          MaterialPageRoute<void>(
            builder: (_) => SaberGamePage(
              server: _server,
              motionEvents: _udpServer.events,
              players: _players,
            ),
          ),
        )
        .then((_) {
          setState(() {
            _eventSubscription = _server.events.listen((event) {
              _trackTrailPacket(event, isUdp: false);
              _handleEvent(event);
            });
            _udpEventSubscription = _udpServer.events.listen((event) {
              _trackTrailPacket(event, isUdp: true);
              _handleEvent(event);
            });
          });
        });
  }

  void _handleSlash(SlashEvent event) {
    final isMatch = event.direction == _targetDirection;
    if (isMatch) {
      _lastSlash = event;
    }
    final result = isMatch ? FeedbackResult.perfect : FeedbackResult.miss;
    final haptic = isMatch ? HapticPattern.perfect : HapticPattern.miss;
    final message = isMatch ? 'Perfect Slash!' : 'Incorrect direction!';

    _server.sendToPlayer(
      event.playerId,
      FeedbackEvent(
        playerId: event.playerId,
        timestamp: DateTime.now(),
        result: result,
        haptic: haptic,
        durationMs: isMatch ? 100 : 150,
        message: message,
      ),
    );
  }

  void _handleMotionTrail(MotionTrailEvent event) {
    _trailBuffer.addEvent(event);
  }

  List<TrailRenderPoint> get _trailPoints => _trailBuffer.points;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final host = _host;

    return Scaffold(
      appBar: AppBar(title: const Text('Room')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              'Connect a phone',
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Start the controller on your phone, then connect with the room address below.',
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 20),
            _ConnectionBanner(status: _status, errorMessage: _errorMessage),
            const SizedBox(height: 16),
            GameShellPage(
              status: _status,
              players: _players,
              trailPoints: _trailPoints,
              trailTransportLabel: _udpTrailPacketsReceived > 0
                  ? 'UDP $_udpTrailPacketsReceived'
                  : 'WS $_webSocketTrailPacketsReceived',
              lastSlash: _lastSlash,
              lastEventLabel: _eventLog.isEmpty ? 'none' : _eventLog.first,
              targetDirection: _targetDirection,
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Manual connection',
                      style: theme.textTheme.titleLarge,
                    ),
                    const SizedBox(height: 14),
                    SelectableText(
                      host?.connectionUri ?? 'Starting server...',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Container(
                      height: 160,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: theme.colorScheme.outlineVariant,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: host == null
                            ? Text(
                                'QR Code pending server start',
                                textAlign: TextAlign.center,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              )
                            : QrImageView(
                                data: host.connectionUri,
                                size: 132,
                                backgroundColor: Colors.white,
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Players (${_players.where((p) => p.status == PlayerConnectionStatus.connected).length})',
                  style: theme.textTheme.titleLarge,
                ),
                if (_players.any(
                  (p) => p.status == PlayerConnectionStatus.connected,
                ))
                  FilledButton.icon(
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('Start Motion Saber'),
                    onPressed: _startGame,
                  ),
              ],
            ),
            const SizedBox(height: 8),
            if (_players.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Row(
                    children: [
                      PulsingDot(color: Colors.green, size: 8, pulseScale: 2.2),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text('Waiting for controller connection...'),
                      ),
                    ],
                  ),
                ),
              )
            else
              for (final player in _players) ...[
                Builder(
                  builder: (context) {
                    final isDisconnected =
                        player.status == PlayerConnectionStatus.disconnected;
                    return Card(
                      color: isDisconnected
                          ? theme.colorScheme.surfaceContainerHighest
                                .withValues(alpha: 0.5)
                          : null,
                      child: ListTile(
                        enabled: !isDisconnected,
                        leading: Icon(
                          isDisconnected
                              ? Icons.portable_wifi_off
                              : Icons.phone_android,
                          color: isDisconnected
                              ? theme.colorScheme.onSurfaceVariant.withValues(
                                  alpha: 0.5,
                                )
                              : null,
                        ),
                        title: Row(
                          children: [
                            Text(
                              player.name,
                              style: TextStyle(
                                decoration: isDisconnected
                                    ? TextDecoration.lineThrough
                                    : null,
                                color: isDisconnected
                                    ? theme.colorScheme.onSurfaceVariant
                                          .withValues(alpha: 0.5)
                                    : null,
                              ),
                            ),
                            if (!isDisconnected) ...[
                              const SizedBox(width: 8),
                              const PulsingDot(color: Colors.green, size: 6),
                            ],
                          ],
                        ),
                        subtitle: Text(
                          player.deviceLabel,
                          style: TextStyle(
                            color: isDisconnected
                                ? theme.colorScheme.onSurfaceVariant.withValues(
                                    alpha: 0.5,
                                  )
                                : null,
                          ),
                        ),
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: isDisconnected
                                ? theme.colorScheme.errorContainer
                                : theme.colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            isDisconnected ? 'Disconnected' : 'Connected',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: isDisconnected
                                  ? theme.colorScheme.onErrorContainer
                                  : theme.colorScheme.onPrimaryContainer,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ],
            const SizedBox(height: 16),
            Text('Event log', style: theme.textTheme.titleLarge),
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: _eventLog.isEmpty
                    ? const Text('No events yet.')
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (final entry in _eventLog)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 6),
                              child: Text(entry),
                            ),
                        ],
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ConnectionBanner extends StatelessWidget {
  const _ConnectionBanner({required this.status, required this.errorMessage});

  final ConnectionStatus status;
  final String? errorMessage;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isError =
        status == ConnectionStatus.error ||
        status == ConnectionStatus.unsupported;

    return Card(
      color: isError
          ? theme.colorScheme.errorContainer
          : theme.colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            status == ConnectionStatus.starting
                ? SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                  )
                : Icon(
                    isError ? Icons.error_outline : Icons.wifi_tethering,
                    color: isError
                        ? theme.colorScheme.onErrorContainer
                        : theme.colorScheme.onPrimaryContainer,
                  ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'Room status: ${status.label}',
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: isError
                              ? theme.colorScheme.onErrorContainer
                              : theme.colorScheme.onPrimaryContainer,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (!isError && status == ConnectionStatus.connected) ...[
                        const SizedBox(width: 8),
                        const PulsingDot(color: Colors.green, size: 8),
                      ] else if (status == ConnectionStatus.starting) ...[
                        const SizedBox(width: 8),
                        const PulsingDot(color: Colors.blue, size: 8),
                      ],
                    ],
                  ),
                  if (errorMessage != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      errorMessage!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onErrorContainer,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
