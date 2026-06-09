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
    final theme = Theme.of(context);
    final stats = _state.playerStats;
    final leader = stats.isEmpty ? null : stats.first;
    final score = leader?.score ?? 0;
    final streak = leader?.streak ?? 0;
    final bestStreak = leader?.bestStreak ?? 0;
    final difficulty = _state.difficulty;

    return Scaffold(
      backgroundColor: const Color(0xFF07111F),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white70),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'BASKETBALL',
                      style: theme.textTheme.headlineMedium?.copyWith(
                        color: const Color(0xFFFFB86B),
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2,
                      ),
                    ),
                  ),
                  _PillBadge(
                    label: 'SCORE',
                    value: score.toString(),
                    color: const Color(0xFFFFB86B),
                  ),
                  const SizedBox(width: 10),
                  _PillBadge(
                    label: 'STREAK',
                    value: streak.toString(),
                    color: const Color(0xFF5EEAD4),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.18),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.28),
                          blurRadius: 18,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(9),
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          _arenaSize = Size(
                            constraints.maxWidth,
                            constraints.maxHeight,
                          );
                          _state.setArenaSize(_arenaSize);
                          return Stack(
                            children: [
                              Positioned.fill(
                                child: CustomPaint(
                                  painter: BasketballPainter(
                                    state: _state,
                                    repaint: _frameClock,
                                  ),
                                ),
                              ),
                              Positioned(
                                left: 16,
                                right: 16,
                                top: 14,
                                child: _ArenaStatusBar(
                                  status: _state.lastEventLabel,
                                  difficulty: difficulty.label,
                                  bestStreak: bestStreak,
                                ),
                              ),
                              if (_state.phase == BasketballRunPhase.countdown)
                                _CountdownOverlay(
                                  countdown: _state.countdownRemaining,
                                ),
                            ],
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 2,
                    child: _InfoPanel(
                      title: 'LAST',
                      value: _lastResultLabel(),
                      subtitle: _lastShotSubtitle(),
                      color: _lastResultColor(),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: _InfoPanel(
                      title: 'DIFFICULTY',
                      value: difficulty.label,
                      subtitle:
                          'Hoop ${difficulty.hoopSpeed == 0 ? 'fixed' : 'moving'}',
                      color: const Color(0xFF5EEAD4),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(flex: 3, child: _LeaderboardPanel(stats: stats)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _lastResultLabel() {
    return switch (_state.lastOutcome) {
      BasketballShotOutcome.scored => 'MADE',
      BasketballShotOutcome.missed => 'MISS',
      BasketballShotOutcome.inFlight =>
        _state.currentBall == null ? 'READY' : 'SHOT',
    };
  }

  Color _lastResultColor() {
    return switch (_state.lastOutcome) {
      BasketballShotOutcome.scored => const Color(0xFF86EFAC),
      BasketballShotOutcome.missed => const Color(0xFFFF6B6B),
      BasketballShotOutcome.inFlight => const Color(0xFFFFB86B),
    };
  }

  String _lastShotSubtitle() {
    final shot = _state.lastShot;
    if (shot == null) {
      return 'Hold, throw, release';
    }
    return 'P ${shot.power.toStringAsFixed(2)}  A ${shot.angle.round()}  O ${shot.offset.toStringAsFixed(2)}';
  }
}

class _ArenaStatusBar extends StatelessWidget {
  const _ArenaStatusBar({
    required this.status,
    required this.difficulty,
    required this.bestStreak,
  });

  final String status;
  final String difficulty;
  final int bestStreak;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _SmallBadge(label: status, icon: Icons.sports_basketball),
        const Spacer(),
        _SmallBadge(label: difficulty, icon: Icons.speed),
        const SizedBox(width: 8),
        _SmallBadge(label: 'Best $bestStreak', icon: Icons.emoji_events),
      ],
    );
  }
}

class _SmallBadge extends StatelessWidget {
  const _SmallBadge({required this.label, required this.icon});

  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.34),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: Colors.white70),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PillBadge extends StatelessWidget {
  const _PillBadge({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.42)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                color: color.withValues(alpha: 0.72),
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              value,
              style: TextStyle(
                color: color,
                fontSize: 16,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
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
        child: Container(
          color: Colors.black.withValues(alpha: 0.22),
          child: Center(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 160),
              child: Text(
                value,
                key: ValueKey(value),
                style: Theme.of(context).textTheme.displayLarge?.copyWith(
                  color: const Color(0xFFFFB86B),
                  fontWeight: FontWeight.w900,
                  shadows: [
                    const Shadow(color: Color(0xFFFFB86B), blurRadius: 22),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _InfoPanel extends StatelessWidget {
  const _InfoPanel({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.color,
  });

  final String title;
  final String value;
  final String subtitle;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      height: 110,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: theme.textTheme.labelSmall?.copyWith(
              color: color.withValues(alpha: 0.76),
              fontWeight: FontWeight.w800,
              letterSpacing: 1.1,
            ),
          ),
          Text(
            value,
            style: theme.textTheme.headlineSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w900,
            ),
          ),
          Text(
            subtitle,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(color: Colors.white60),
          ),
        ],
      ),
    );
  }
}

class _LeaderboardPanel extends StatelessWidget {
  const _LeaderboardPanel({required this.stats});

  final List<BasketballPlayerStats> stats;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      height: 110,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'PLAYERS',
            style: theme.textTheme.labelSmall?.copyWith(
              color: Colors.white54,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: stats.isEmpty
                ? const Center(
                    child: Text(
                      'No players connected',
                      style: TextStyle(color: Colors.white54),
                    ),
                  )
                : ListView.builder(
                    itemCount: stats.length,
                    itemBuilder: (context, index) {
                      final item = stats[index];
                      final disconnected =
                          item.player.status ==
                          PlayerConnectionStatus.disconnected;
                      return Row(
                        children: [
                          SizedBox(
                            width: 28,
                            child: Text(
                              '#${index + 1}',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          Expanded(
                            child: Text(
                              item.player.name,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: disconnected
                                    ? Colors.white38
                                    : Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          Text(
                            '${item.score}',
                            style: const TextStyle(
                              color: Color(0xFFFFB86B),
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            '${item.streak}x',
                            style: const TextStyle(
                              color: Color(0xFF5EEAD4),
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
