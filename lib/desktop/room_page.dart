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
import '../games/basketball/basketball_game_page.dart';
import 'game_shell_page.dart';
import '../games/saber/saber_game_page.dart';
import '../shared/feedback/audio_service.dart';

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
  int _trailSamplesReceived = 0;
  int _lastUdpTrailPacketsReceived = 0;
  int _lastWebSocketTrailPacketsReceived = 0;
  int _lastTrailSamplesReceived = 0;
  int _udpTrailPacketsPerSecond = 0;
  int _webSocketTrailPacketsPerSecond = 0;
  int _trailSamplesPerSecond = 0;
  DateTime? _lastUdpTrailPacketAt;
  DateTime? _lastWebSocketTrailPacketAt;
  double? _udpAverageArrivalGapMs;
  double? _webSocketAverageArrivalGapMs;
  GameId _selectedGame = GameId.motionSaber;

  MotionDirection _targetDirection = MotionDirection.up;
  Timer? _targetDirectionTimer;
  Timer? _trailPruneTimer;
  Timer? _trailStatsTimer;

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
    _trailStatsTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _udpTrailPacketsPerSecond =
            _udpTrailPacketsReceived - _lastUdpTrailPacketsReceived;
        _webSocketTrailPacketsPerSecond =
            _webSocketTrailPacketsReceived - _lastWebSocketTrailPacketsReceived;
        _trailSamplesPerSecond =
            _trailSamplesReceived - _lastTrailSamplesReceived;
        _lastUdpTrailPacketsReceived = _udpTrailPacketsReceived;
        _lastWebSocketTrailPacketsReceived = _webSocketTrailPacketsReceived;
        _lastTrailSamplesReceived = _trailSamplesReceived;
      });
    });

    unawaited(AudioService().playBGM('audio/bgm_lobby.wav'));
  }

  @override
  void dispose() {
    unawaited(AudioService().stopBGM());
    _targetDirectionTimer?.cancel();
    _trailPruneTimer?.cancel();
    _trailStatsTimer?.cancel();
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
      onGameCommand: _handleGameCommand,
    );

    if (event is MotionTrailEvent) {
      dispatcher.dispatch(event);
    } else if (event is GameCommandEvent) {
      setState(() {
        _eventLog.insert(0, '${event.command.name} from ${event.playerId}');
        if (_eventLog.length > 8) {
          _eventLog.removeLast();
        }
      });
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
    final now = DateTime.now();
    _trailSamplesReceived += event.samples.length;
    if (isUdp) {
      _udpTrailPacketsReceived++;
      _udpAverageArrivalGapMs = _recordArrivalGap(
        previous: _lastUdpTrailPacketAt,
        current: now,
        averageMs: _udpAverageArrivalGapMs,
      );
      _lastUdpTrailPacketAt = now;
    } else {
      _webSocketTrailPacketsReceived++;
      _webSocketAverageArrivalGapMs = _recordArrivalGap(
        previous: _lastWebSocketTrailPacketAt,
        current: now,
        averageMs: _webSocketAverageArrivalGapMs,
      );
      _lastWebSocketTrailPacketAt = now;
    }
  }

  double? _recordArrivalGap({
    required DateTime? previous,
    required DateTime current,
    required double? averageMs,
  }) {
    if (previous == null) {
      return averageMs;
    }

    final gapMs = current.difference(previous).inMilliseconds.toDouble();
    if (averageMs == null) {
      return gapMs;
    }
    return averageMs * 0.8 + gapMs * 0.2;
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
    _sendRoomStateToPlayer(event.playerId);
    _broadcastRoomState();

    unawaited(AudioService().playSFX('audio/sfx_click.wav'));
  }

  int get _connectedPlayersCount => _players
      .where((player) => player.status == PlayerConnectionStatus.connected)
      .length;

  RoomStateEvent _buildRoomState({String? message}) {
    final scores = [
      for (var i = 0; i < _players.length; i++)
        PlayerScoreSnapshot(
          playerId: _players[i].id,
          name: _players[i].name,
          score: 0,
          combo: 0,
          maxCombo: 0,
          hits: 0,
          misses: 0,
          rank: i + 1,
          connected: _players[i].status == PlayerConnectionStatus.connected,
        ),
    ];

    final isPlayableGame = _isPlayableGame(_selectedGame);

    return RoomStateEvent(
      playerId: 'host',
      timestamp: DateTime.now(),
      selectedGame: _selectedGame,
      availableGames: GameId.values,
      roomPhase: RoomPhase.lobby,
      playerScores: scores,
      connectedPlayers: _connectedPlayersCount,
      canStart: _connectedPlayersCount > 0 && isPlayableGame,
      canRestart: false,
      canBackToRoom: false,
      sharedLives: _selectedGame == GameId.motionSaber ? 3 : 0,
      maxSharedLives: _selectedGame == GameId.motionSaber ? 3 : 0,
      survivedSeconds: 0,
      message: message,
    );
  }

  void _broadcastRoomState({String? message}) {
    _server.broadcast(_buildRoomState(message: message));
  }

  void _sendRoomStateToPlayer(String playerId, {String? message}) {
    _server.sendToPlayer(playerId, _buildRoomState(message: message));
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
      _broadcastRoomState();
    }
  }

  void _handleGameCommand(GameCommandEvent event) {
    switch (event.command) {
      case GameCommand.selectGame:
        final gameId = event.gameId;
        if (gameId == null) {
          _sendRoomStateToPlayer(event.playerId, message: 'No game selected.');
          return;
        }
        setState(() {
          _selectedGame = gameId;
        });
        _broadcastRoomState(message: '${_gameLabel(gameId)} selected.');
      case GameCommand.startGame:
        if (!_isPlayableGame(_selectedGame)) {
          _broadcastRoomState(
            message: '${_gameLabel(_selectedGame)} is planned next.',
          );
          return;
        }
        if (_connectedPlayersCount == 0) {
          _sendRoomStateToPlayer(
            event.playerId,
            message: 'Connect at least one player first.',
          );
          return;
        }
        _startGame();
      case GameCommand.restartGame:
        _sendRoomStateToPlayer(
          event.playerId,
          message: 'Start a game before restarting.',
        );
      case GameCommand.backToRoom:
        _broadcastRoomState(message: 'Already in room.');
    }
  }

  void _startGame() {
    if (!_isPlayableGame(_selectedGame)) {
      _broadcastRoomState(
        message: '${_gameLabel(_selectedGame)} is planned next.',
      );
      return;
    }

    final selectedGame = _selectedGame;

    _eventSubscription?.cancel();
    _udpEventSubscription?.cancel();
    _eventSubscription = null;
    _udpEventSubscription = null;

    unawaited(AudioService().stopBGM());

    Navigator.of(context)
        .push(
          MaterialPageRoute<void>(
            builder: (_) => switch (selectedGame) {
              GameId.motionSaber => SaberGamePage(
                server: _server,
                motionEvents: _udpServer.events,
                players: _players,
              ),
              GameId.basketball => BasketballGamePage(
                server: _server,
                motionEvents: _udpServer.events,
                players: _players,
              ),
              GameId.pingPong => SaberGamePage(
                server: _server,
                motionEvents: _udpServer.events,
                players: _players,
              ),
            },
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
          _broadcastRoomState(message: 'Back in room.');
          unawaited(AudioService().playBGM('audio/bgm_lobby.wav'));
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
  int get _trailPacketsPerSecond =>
      _udpTrailPacketsPerSecond + _webSocketTrailPacketsPerSecond;
  double? get _activeTrailAverageGapMs => _udpTrailPacketsReceived > 0
      ? _udpAverageArrivalGapMs
      : _webSocketAverageArrivalGapMs;

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
                  ? 'UDP ${_udpTrailPacketsPerSecond}p/s'
                  : 'WS ${_webSocketTrailPacketsPerSecond}p/s',
              lastSlash: _lastSlash,
              lastEventLabel: _eventLog.isEmpty ? 'none' : _eventLog.first,
              targetDirection: _targetDirection,
            ),
            const SizedBox(height: 16),
            _TrailDiagnosticsCard(
              transport: _udpTrailPacketsReceived > 0 ? 'UDP' : 'WebSocket',
              packetsPerSecond: _trailPacketsPerSecond,
              samplesPerSecond: _trailSamplesPerSecond,
              averageGapMs: _activeTrailAverageGapMs,
              trailPoints: _trailPoints.length,
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
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(
                      Icons.sports_esports,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Selected game: ${_gameLabel(_selectedGame)}',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Text(
                      'Phone control ready',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
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
                    label: Text('Start ${_shortGameLabel(_selectedGame)}'),
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
    GameId.basketball => 'Basketball',
    GameId.pingPong => 'Ping Pong',
  };
}

bool _isPlayableGame(GameId gameId) {
  return switch (gameId) {
    GameId.motionSaber || GameId.basketball => true,
    GameId.pingPong => false,
  };
}

class _TrailDiagnosticsCard extends StatelessWidget {
  const _TrailDiagnosticsCard({
    required this.transport,
    required this.packetsPerSecond,
    required this.samplesPerSecond,
    required this.averageGapMs,
    required this.trailPoints,
  });

  final String transport;
  final int packetsPerSecond;
  final int samplesPerSecond;
  final double? averageGapMs;
  final int trailPoints;

  @override
  Widget build(BuildContext context) {
    final gap = averageGapMs;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.query_stats,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 10),
                Text(
                  'Trail diagnostics',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _TrailMetric(label: 'Transport', value: transport),
                _TrailMetric(label: 'Packets/s', value: '$packetsPerSecond'),
                _TrailMetric(label: 'Samples/s', value: '$samplesPerSecond'),
                _TrailMetric(
                  label: 'Avg gap',
                  value: gap == null ? '-' : '${gap.round()}ms',
                ),
                _TrailMetric(label: 'Points', value: '$trailPoints'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _TrailMetric extends StatelessWidget {
  const _TrailMetric({required this.label, required this.value});

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
