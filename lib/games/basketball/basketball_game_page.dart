import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../network/websocket_server_service.dart';
import '../../shared/models/motion_event.dart';
import '../../shared/models/player.dart';
import 'basketball_game_state.dart';
import 'basketball_painter.dart';
import 'basketball_physics.dart';

class BasketballGamePage extends StatefulWidget {
  const BasketballGamePage({
    super.key,
    required this.server,
    required this.players,
    this.motionEvents,
  });

  final WebSocketServerService server;
  final List<Player> players;
  final Stream<MotionEvent>? motionEvents;

  @override
  State<BasketballGamePage> createState() => _BasketballGamePageState();
}

class _BasketballGamePageState extends State<BasketballGamePage>
    with SingleTickerProviderStateMixin {
  late final BasketballGameState _state;
  late final Ticker _ticker;
  StreamSubscription<MotionEvent>? _commandSubscription;
  final ValueNotifier<DateTime> _frameClock = ValueNotifier(DateTime.now());
  Duration _lastElapsed = Duration.zero;
  Size _arenaSize = const Size(800, 450);
  bool _resetNextTick = false;
  DateTime? _lastRoomStateBroadcastAt;

  @override
  void initState() {
    super.initState();
    _state = BasketballGameState(
      server: widget.server,
      initialPlayers: widget.players,
      motionEvents: widget.motionEvents,
    );
    _state.addListener(_onStateChange);
    _commandSubscription = widget.server.events.listen(_handleCommandEvent);
    _ticker = createTicker((elapsed) {
      if (_resetNextTick) {
        _lastElapsed = elapsed;
        _resetNextTick = false;
      }
      final dt =
          (elapsed.inMicroseconds - _lastElapsed.inMicroseconds) / 1000000.0;
      _lastElapsed = elapsed;
      _state.update(dt, _arenaSize);
      _frameClock.value = DateTime.now();
    });
    _ticker.start();
    _broadcastRoomState(force: true);
  }

  @override
  void dispose() {
    _ticker.dispose();
    unawaited(_commandSubscription?.cancel());
    _state.removeListener(_onStateChange);
    _state.dispose();
    _frameClock.dispose();
    super.dispose();
  }

  void _onStateChange() {
    if (mounted) {
      setState(() {});
    }
    _broadcastRoomState(
      force: _state.lastOutcome != BasketballShotOutcome.inFlight,
    );
  }

  void _restartRun() {
    _resetNextTick = true;
    _state.restartRun();
    _frameClock.value = DateTime.now();
    _broadcastRoomState(force: true, message: 'Basketball restarted.');
  }

  void _handleCommandEvent(MotionEvent event) {
    if (event is! GameCommandEvent) {
      return;
    }

    switch (event.command) {
      case GameCommand.restartGame:
        if (event.gameId == null || event.gameId == GameId.basketball) {
          _restartRun();
        }
      case GameCommand.backToRoom:
        _broadcastRoomState(force: true, message: 'Returning to room.');
        if (mounted) {
          Navigator.of(context).pop();
        }
      case GameCommand.startGame:
      case GameCommand.selectGame:
        _broadcastRoomState(force: true);
    }
  }

  void _broadcastRoomState({bool force = false, String? message}) {
    final now = DateTime.now();
    final lastBroadcast = _lastRoomStateBroadcastAt;
    if (!force &&
        lastBroadcast != null &&
        now.difference(lastBroadcast).inMilliseconds < 250) {
      return;
    }
    _lastRoomStateBroadcastAt = now;

    widget.server.broadcast(
      RoomStateEvent(
        playerId: 'host',
        timestamp: now,
        selectedGame: GameId.basketball,
        availableGames: GameId.values,
        roomPhase: switch (_state.phase) {
          BasketballRunPhase.countdown => RoomPhase.countdown,
          BasketballRunPhase.playing => RoomPhase.playing,
        },
        playerScores: _scoreSnapshots(),
        connectedPlayers: _state.players
            .where((p) => p.status == PlayerConnectionStatus.connected)
            .length,
        canStart: false,
        canRestart: true,
        canBackToRoom: true,
        sharedLives: 0,
        maxSharedLives: 0,
        survivedSeconds: _state.playingSeconds,
        message: message ?? _state.lastEventLabel,
      ),
    );
  }

  List<PlayerScoreSnapshot> _scoreSnapshots() {
    final stats = _state.playerStats;
    return [
      for (var i = 0; i < stats.length; i++)
        PlayerScoreSnapshot(
          playerId: stats[i].player.id,
          name: stats[i].player.name,
          score: stats[i].score,
          combo: stats[i].streak,
          maxCombo: stats[i].bestStreak,
          hits: stats[i].hits,
          misses: stats[i].misses,
          rank: i + 1,
          connected: stats[i].player.status == PlayerConnectionStatus.connected,
        ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final stats = _state.playerStats;
    final leader = stats.isEmpty ? null : stats.first;
    final score = leader?.score ?? 0;
    final streak = leader?.streak ?? 0;
    final bestStreak = leader?.bestStreak ?? 0;
    final playerName = leader?.player.name ?? 'Player';

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  _arenaSize = Size(
                    constraints.maxWidth,
                    constraints.maxHeight,
                  );
                  _state.setArenaSize(_arenaSize);
                  return CustomPaint(
                    painter: BasketballPainter(
                      state: _state,
                      repaint: _frameClock,
                    ),
                  );
                },
              ),
            ),
            Positioned(
              left: 4,
              top: 0,
              child: TextButton.icon(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.chevron_left, size: 18),
                label: const Text('Back'),
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF2563EB),
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  minimumSize: const Size(0, 36),
                ),
              ),
            ),
            Positioned(
              top: 4,
              left: 0,
              right: 0,
              child: Center(
                child: _TinyStat(label: 'HIGH SCORE', value: '$bestStreak'),
              ),
            ),
            Positioned(
              top: 4,
              right: 12,
              child: _TinyStat(label: 'STREAK', value: '$streak'),
            ),
            Positioned.fill(
              child: IgnorePointer(
                child: Center(
                  child: Text(
                    '$score',
                    style: const TextStyle(
                      color: Color(0xFF71717A),
                      fontSize: 76,
                      fontWeight: FontWeight.w200,
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              left: 12,
              right: 12,
              bottom: 10,
              child: _BottomStatus(
                playerName: playerName,
                status: _state.lastEventLabel,
                stats: stats,
              ),
            ),
            if (_state.phase == BasketballRunPhase.countdown)
              _CountdownOverlay(countdown: _state.countdownRemaining),
          ],
        ),
      ),
    );
  }
}

class _TinyStat extends StatelessWidget {
  const _TinyStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF18181B),
            fontSize: 10,
            fontWeight: FontWeight.w500,
            height: 1,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            color: Color(0xFF18181B),
            fontSize: 16,
            fontWeight: FontWeight.w500,
            height: 1,
          ),
        ),
      ],
    );
  }
}

class _BottomStatus extends StatelessWidget {
  const _BottomStatus({
    required this.playerName,
    required this.status,
    required this.stats,
  });

  final String playerName;
  final String status;
  final List<BasketballPlayerStats> stats;

  @override
  Widget build(BuildContext context) {
    final visibleStats = stats.take(3).toList();

    return Row(
      children: [
        Expanded(
          child: Text(
            '$playerName · $status',
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFF52525B),
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        for (final stat in visibleStats)
          Padding(
            padding: const EdgeInsets.only(left: 10),
            child: Text(
              '${stat.player.name} ${stat.score}',
              style: const TextStyle(
                color: Color(0xFF71717A),
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
      ],
    );
  }
}

class _CountdownOverlay extends StatelessWidget {
  const _CountdownOverlay({required this.countdown});

  final double countdown;

  @override
  Widget build(BuildContext context) {
    final value = countdown.ceil().clamp(1, 3).toString();

    return Positioned.fill(
      child: IgnorePointer(
        child: ColoredBox(
          color: Colors.white.withValues(alpha: 0.72),
          child: Center(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 160),
              child: Text(
                value,
                key: ValueKey(value),
                style: const TextStyle(
                  color: Color(0xFF71717A),
                  fontSize: 96,
                  fontWeight: FontWeight.w200,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
