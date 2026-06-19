import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../network/websocket_server_service.dart';
import '../../shared/models/motion_event.dart';
import '../../shared/models/player.dart';
import '../../shared/feedback/audio_service.dart';
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

  ShootEvent? _lastShotSeen;
  BasketballShotOutcome _lastOutcomeSeen = BasketballShotOutcome.inFlight;
  int _lastCollisionCountSeen = 0;
  bool _wasGameOverSeen = false;
  bool _alternatePitch = false;

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

    unawaited(AudioService().playSFX('audio/sfx_countdown.wav'));
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
    final ball = _state.currentBall;
    if (ball != null) {
      if (ball.collisionCount > _lastCollisionCountSeen) {
        _lastCollisionCountSeen = ball.collisionCount;
        // Alternate pitch for successive collisions + small random variance (±0.02)
        _alternatePitch = !_alternatePitch;
        final basePitch = _alternatePitch ? 1.06 : 0.94;
        final finalPitch = basePitch + (math.Random().nextDouble() * 0.04 - 0.02);
        if (ball.lastCollision == BasketballCollisionType.rim) {
          unawaited(AudioService().playSFX('audio/sfx_basketball_rim.wav', pitch: finalPitch));
        } else if (ball.lastCollision == BasketballCollisionType.backboard) {
          unawaited(AudioService().playSFX('audio/sfx_basketball_backboard.wav', pitch: finalPitch));
        }
      }
    } else {
      _lastCollisionCountSeen = 0;
    }

    final shot = _state.lastShot;
    if (shot != null && shot != _lastShotSeen) {
      _lastShotSeen = shot;
      unawaited(AudioService().playSFX('audio/sfx_basketball_shoot.wav'));
    }

    if (_state.lastOutcome != _lastOutcomeSeen) {
      _lastOutcomeSeen = _state.lastOutcome;
      if (_state.lastOutcome == BasketballShotOutcome.scored) {
        // Keep swish at 1.0 pitch so the scoring splash/friction sounds natural and clear
        unawaited(AudioService().playSFX('audio/sfx_basketball_swish.wav', pitch: 1.0));
      }
    }

    if (_state.isGameOver && !_wasGameOverSeen) {
      _wasGameOverSeen = true;
      unawaited(AudioService().playSFX('audio/sfx_saber_miss.wav'));
    }

    if (mounted) {
      setState(() {});
    }
    _broadcastRoomState(
      force:
          _state.isGameOver ||
          _state.lastOutcome != BasketballShotOutcome.inFlight,
    );
  }

  void _restartRun() {
    _lastShotSeen = null;
    _lastOutcomeSeen = BasketballShotOutcome.inFlight;
    _lastCollisionCountSeen = 0;
    _wasGameOverSeen = false;
    _resetNextTick = true;
    _state.restartRun();
    _frameClock.value = DateTime.now();
    _broadcastRoomState(force: true, message: 'Basketball restarted.');
    unawaited(AudioService().playSFX('audio/sfx_countdown.wav'));
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
          BasketballRunPhase.gameOver => RoomPhase.gameOver,
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
    final remainingTime = _formatDuration(_state.remainingSeconds);

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
                child: _TinyStat(label: 'TIME', value: remainingTime),
              ),
            ),
            Positioned(
              top: 4,
              right: 12,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _TinyStat(label: 'HIGH SCORE', value: '$bestStreak'),
                  const SizedBox(width: 14),
                  _TinyStat(label: 'STREAK', value: '$streak'),
                ],
              ),
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
            if (_state.isGameOver)
              _BasketballResultsOverlay(
                stats: stats,
                durationSeconds: _state.playingSeconds,
                onRetry: _restartRun,
                onBack: () => Navigator.of(context).pop(),
              ),
          ],
        ),
      ),
    );
  }
}

String _formatDuration(double seconds) {
  final wholeSeconds = seconds.ceil().clamp(0, 5999);
  final minutes = wholeSeconds ~/ 60;
  final remainingSeconds = wholeSeconds % 60;
  return '$minutes:${remainingSeconds.toString().padLeft(2, '0')}';
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

class _BasketballResultsOverlay extends StatelessWidget {
  const _BasketballResultsOverlay({
    required this.stats,
    required this.durationSeconds,
    required this.onRetry,
    required this.onBack,
  });

  final List<BasketballPlayerStats> stats;
  final double durationSeconds;
  final VoidCallback onRetry;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final winner = stats.isEmpty ? null : stats.first;
    final visibleStats = stats.take(4).toList();

    return Positioned.fill(
      child: ColoredBox(
        color: Colors.white.withValues(alpha: 0.86),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: const Color(0xFFE4E4E7)),
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 24,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(22),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'TIME UP',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          color: const Color(0xFF18181B),
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _ResultMetric(
                            label: 'WINNER',
                            value: winner?.player.name ?? '-',
                          ),
                          const SizedBox(width: 12),
                          _ResultMetric(
                            label: 'SCORE',
                            value: '${winner?.score ?? 0}',
                          ),
                          const SizedBox(width: 12),
                          _ResultMetric(
                            label: 'TIME',
                            value: _formatDuration(durationSeconds),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      if (visibleStats.isNotEmpty)
                        _ResultsTable(stats: visibleStats),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(
                            child: FilledButton.icon(
                              onPressed: onRetry,
                              icon: const Icon(Icons.replay),
                              label: const Text('Restart'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: onBack,
                              icon: const Icon(Icons.chevron_left),
                              label: const Text('Room'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ResultsTable extends StatelessWidget {
  const _ResultsTable({required this.stats});

  final List<BasketballPlayerStats> stats;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      children: [
        for (var i = 0; i < stats.length; i++)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Row(
              children: [
                SizedBox(
                  width: 34,
                  child: Text(
                    '#${i + 1}',
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: const Color(0xFF71717A),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    stats[i].player.name,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: const Color(0xFF18181B),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                _InlineStat(label: 'PTS', value: '${stats[i].score}'),
                _InlineStat(label: 'BEST', value: '${stats[i].bestStreak}'),
                _InlineStat(
                  label: 'FG',
                  value: '${stats[i].hits}/${stats[i].attempts}',
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _InlineStat extends StatelessWidget {
  const _InlineStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 54,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFFA1A1AA),
              fontSize: 9,
              fontWeight: FontWeight.w700,
              height: 1,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Color(0xFF18181B),
              fontSize: 13,
              fontWeight: FontWeight.w700,
              height: 1.15,
            ),
          ),
        ],
      ),
    );
  }
}

class _ResultMetric extends StatelessWidget {
  const _ResultMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            label,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFFA1A1AA),
              fontSize: 10,
              fontWeight: FontWeight.w700,
              height: 1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFF18181B),
              fontSize: 22,
              fontWeight: FontWeight.w700,
              height: 1,
            ),
          ),
        ],
      ),
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
