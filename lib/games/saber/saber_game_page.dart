import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import '../../network/websocket_server_service.dart';
import '../../shared/models/motion_event.dart';
import '../../shared/models/player.dart';
import '../../shared/visual/particle_system.dart';
import '../../shared/visual/screen_shake_controller.dart';
import '../../shared/visual/trail_impact_locator.dart';
import 'saber_game_state.dart';
import 'saber_painter.dart';
import 'saber_visual_style.dart';

class SaberGamePage extends StatefulWidget {
  const SaberGamePage({
    super.key,
    required this.server,
    required this.players,
    this.motionEvents,
  });

  final WebSocketServerService server;
  final List<Player> players;
  final Stream<MotionEvent>? motionEvents;

  @override
  State<SaberGamePage> createState() => _SaberGamePageState();
}

class _SaberGamePageState extends State<SaberGamePage>
    with SingleTickerProviderStateMixin {
  late final SaberGameState _state;
  late final Ticker _ticker;
  StreamSubscription<MotionEvent>? _commandSubscription;
  Duration _lastElapsed = Duration.zero;

  final ScreenShakeController _shakeController = ScreenShakeController();
  final List<Particle> _particles = [];
  final List<_ScorePopEffect> _scorePops = [];
  SaberHitEffect? _lastHitEffectSeen;
  final ValueNotifier<DateTime> _frameClock = ValueNotifier<DateTime>(
    DateTime.now(),
  );
  Size _arenaSize = const Size(800, 450);
  bool? _resetNextTick;
  DateTime? _lastRoomStateBroadcastAt;

  @override
  void initState() {
    super.initState();
    _state = SaberGameState(
      server: widget.server,
      initialPlayers: widget.players,
      motionEvents: widget.motionEvents,
    );
    _state.addListener(_onStateChange);
    _commandSubscription = widget.server.events.listen(_handleCommandEvent);

    _ticker = createTicker((elapsed) {
      if (_resetNextTick == true) {
        _lastElapsed = elapsed;
        _resetNextTick = false;
      }
      final dt =
          (elapsed.inMicroseconds - _lastElapsed.inMicroseconds) / 1000000.0;
      _lastElapsed = elapsed;

      _state.update(dt);
      final now = DateTime.now();
      _particles.removeWhere((p) => !p.isAlive(now));
      _scorePops.removeWhere((effect) => !effect.isAlive(now));
      _frameClock.value = now;
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
    final hitEffect = _state.lastHitEffect;
    if (hitEffect != null && hitEffect != _lastHitEffectSeen) {
      _lastHitEffectSeen = hitEffect;
      final slash = hitEffect.slash;

      _shakeController.trigger(
        intensity: 8.0 + slash.power * 12.0,
        duration: const Duration(milliseconds: 250),
      );

      final origin = const TrailImpactLocator().locate(
        slash: slash,
        points: _state.trailPoints,
        size: _arenaSize,
      );

      final color = saberColorForDirection(hitEffect.targetDirection);

      final now = DateTime.now();
      final burst = const ParticleBurstFactory().createBurst(
        origin: origin,
        now: now,
        color: color,
        count: 24,
        speed: 55.0 + slash.power * 35.0,
      );
      _particles.addAll(burst);
      _scorePops.add(
        _ScorePopEffect(
          origin: origin,
          label: saberScoreLabel(
            result: hitEffect.result,
            addedScore: hitEffect.addedScore,
          ),
          color: saberScoreColorForResult(hitEffect.result),
          createdAt: now,
        ),
      );
      _frameClock.value = now;
    }
    if (mounted) {
      setState(() {});
    }
    _broadcastRoomState(force: _state.isGameOver);
  }

  void _restartRun() {
    _particles.clear();
    _scorePops.clear();
    _lastHitEffectSeen = null;
    _resetNextTick = true;
    _state.restartRun();
    _frameClock.value = DateTime.now();
    _broadcastRoomState(force: true);
  }

  void _handleCommandEvent(MotionEvent event) {
    if (event is! GameCommandEvent) {
      return;
    }

    switch (event.command) {
      case GameCommand.restartGame:
        if (event.gameId == null || event.gameId == GameId.motionSaber) {
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
        selectedGame: GameId.motionSaber,
        availableGames: GameId.values,
        roomPhase: switch (_state.phase) {
          SaberRunPhase.countdown => RoomPhase.countdown,
          SaberRunPhase.playing => RoomPhase.playing,
          SaberRunPhase.gameOver => RoomPhase.gameOver,
        },
        playerScores: _scoreSnapshots(),
        connectedPlayers: _state.players
            .where(
              (player) => player.status == PlayerConnectionStatus.connected,
            )
            .length,
        canStart: false,
        canRestart: true,
        canBackToRoom: true,
        sharedLives: _state.sharedLives,
        maxSharedLives: _state.maxSharedLives,
        survivedSeconds: _state.survivedSeconds,
        message: message,
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
          combo: stats[i].combo,
          maxCombo: stats[i].maxCombo,
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
    final leaderboard = _state.playerStats;
    final topStats = leaderboard.isEmpty ? null : leaderboard.first;
    final topScore = topStats?.score ?? _state.scoring.score;
    final combo = topStats?.combo ?? _state.scoring.combo;
    final maxCombo = topStats?.maxCombo ?? _state.scoring.maxCombo;
    final multiplier = topStats?.multiplier ?? _state.scoring.multiplier;
    final livesColor = _state.sharedLives <= 1
        ? Colors.redAccent
        : Colors.pinkAccent;

    return Scaffold(
      backgroundColor: const Color(0xFF030712),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            children: [
              // Header
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white70),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'MOTION SABER',
                      style: theme.textTheme.headlineMedium?.copyWith(
                        color: Colors.cyanAccent,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2,
                        shadows: [
                          const Shadow(color: Colors.cyan, blurRadius: 10),
                        ],
                      ),
                    ),
                  ),
                  _PillBadge(
                    label: 'LIVES',
                    value: '${_state.sharedLives}/${_state.maxSharedLives}',
                    color: livesColor,
                  ),
                  const SizedBox(width: 10),
                  _PillBadge(
                    label: 'TOP SCORE',
                    value: topScore.toString(),
                    color: Colors.greenAccent,
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Game Arena Screen
              Expanded(
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: Colors.cyan.withValues(alpha: 0.3),
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.cyan.withValues(alpha: 0.05),
                          blurRadius: 20,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        _arenaSize = Size(
                          constraints.maxWidth,
                          constraints.maxHeight,
                        );
                        return Stack(
                          children: [
                            Positioned.fill(
                              child: CustomPaint(
                                painter: SaberPainter(
                                  targets: _state.targets,
                                  trailPoints: _state.trailPoints,
                                  frameClock: _frameClock,
                                  lastSlash: _state.lastSlash,
                                  shakeController: _shakeController,
                                  particles: _particles,
                                ),
                              ),
                            ),
                            Positioned.fill(
                              child: IgnorePointer(
                                child: CustomPaint(
                                  painter: _ScorePopPainter(
                                    effects: _scorePops,
                                    frameClock: _frameClock,
                                  ),
                                ),
                              ),
                            ),
                            if (_state.phase == SaberRunPhase.countdown)
                              _CountdownOverlay(
                                countdown: _state.countdownRemaining,
                              ),
                            if (_state.isGameOver)
                              _GameOverOverlay(
                                score: topScore,
                                survivedSeconds: _state.survivedSeconds,
                                onRetry: _restartRun,
                                onBack: () => Navigator.of(context).pop(),
                              ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Dashboard / HUD
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Combo Card
                  Expanded(
                    flex: 2,
                    child: _InfoCard(
                      title: 'COMBO',
                      value: combo.toString(),
                      subtitle: 'Max: $maxCombo',
                      color: Colors.orangeAccent,
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Multiplier Card
                  Expanded(
                    flex: 2,
                    child: _InfoCard(
                      title: 'MULTIPLIER',
                      value: 'x${multiplier.toStringAsFixed(1)}',
                      subtitle:
                          'Survived: ${_formatDuration(_state.survivedSeconds)}',
                      color: Colors.yellowAccent,
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Player Status Card
                  Expanded(
                    flex: 3,
                    child: Container(
                      height: 110,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1F2937).withValues(alpha: 0.8),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.grey.withValues(alpha: 0.2),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'PLAYER SCORES',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: Colors.grey,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.2,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Expanded(
                            child: leaderboard.isEmpty
                                ? const Center(
                                    child: Text(
                                      'No players connected',
                                      style: TextStyle(color: Colors.grey),
                                    ),
                                  )
                                : ListView.builder(
                                    itemCount: leaderboard.length,
                                    itemBuilder: (context, index) {
                                      final stats = leaderboard[index];
                                      final player = stats.player;
                                      final isDisconnected =
                                          player.status ==
                                          PlayerConnectionStatus.disconnected;
                                      return Row(
                                        children: [
                                          Container(
                                            width: 8,
                                            height: 8,
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              color: isDisconnected
                                                  ? Colors.red
                                                  : Colors.green,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              player.name,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                color: isDisconnected
                                                    ? Colors.grey
                                                    : Colors.white,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            stats.score.toString(),
                                            style: const TextStyle(
                                              color: Colors.greenAccent,
                                              fontWeight: FontWeight.w900,
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          Text(
                                            '${stats.hits}H/${stats.misses}M',
                                            style: TextStyle(
                                              color: Colors.white.withValues(
                                                alpha: 0.62,
                                              ),
                                              fontSize: 12,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ],
                                      );
                                    },
                                  ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _formatDuration(double seconds) {
  final wholeSeconds = seconds.floor();
  final minutes = wholeSeconds ~/ 60;
  final remainingSeconds = wholeSeconds % 60;
  return '$minutes:${remainingSeconds.toString().padLeft(2, '0')}';
}

class _ScorePopEffect {
  const _ScorePopEffect({
    required this.origin,
    required this.label,
    required this.color,
    required this.createdAt,
  });

  final Offset origin;
  final String label;
  final Color color;
  final DateTime createdAt;
  final Duration lifetime = const Duration(milliseconds: 760);

  bool isAlive(DateTime now) => now.difference(createdAt) < lifetime;

  double progress(DateTime now) {
    return (now.difference(createdAt).inMilliseconds / lifetime.inMilliseconds)
        .clamp(0.0, 1.0)
        .toDouble();
  }

  Offset positionAt(DateTime now) {
    final t = progress(now);
    return origin - Offset(0, 46 * t);
  }

  double opacityAt(DateTime now) {
    final t = progress(now);
    if (t < 0.18) {
      return (t / 0.18).clamp(0.0, 1.0).toDouble();
    }
    return (1 - (t - 0.18) / 0.82).clamp(0.0, 1.0).toDouble();
  }
}

class _ScorePopPainter extends CustomPainter {
  _ScorePopPainter({required this.effects, required this.frameClock})
    : super(repaint: frameClock);

  final List<_ScorePopEffect> effects;
  final ValueNotifier<DateTime> frameClock;

  @override
  void paint(Canvas canvas, Size size) {
    final now = frameClock.value;
    for (final effect in effects) {
      if (!effect.isAlive(now)) {
        continue;
      }
      final opacity = effect.opacityAt(now);
      final progress = effect.progress(now);
      final position = effect.positionAt(now);
      final fontSize = 17.0 + (1 - progress) * 5.0;
      final glowColor = effect.color.withValues(alpha: opacity * 0.8);

      final painter = TextPainter(
        text: TextSpan(
          text: effect.label,
          style: TextStyle(
            color: effect.color.withValues(alpha: opacity),
            fontSize: fontSize,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.0,
            shadows: [
              Shadow(color: glowColor, blurRadius: 14),
              Shadow(color: Colors.black.withValues(alpha: opacity * 0.72)),
            ],
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: size.width * 0.56);

      painter.paint(
        canvas,
        position - Offset(painter.width / 2, painter.height / 2),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ScorePopPainter oldDelegate) {
    return oldDelegate.effects != effects ||
        oldDelegate.frameClock != frameClock;
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              color: color.withValues(alpha: 0.7),
              fontSize: 11,
              fontWeight: FontWeight.bold,
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
                  color: Colors.cyanAccent,
                  fontWeight: FontWeight.w900,
                  shadows: [
                    const Shadow(color: Colors.cyanAccent, blurRadius: 22),
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

class _GameOverOverlay extends StatelessWidget {
  const _GameOverOverlay({
    required this.score,
    required this.survivedSeconds,
    required this.onRetry,
    required this.onBack,
  });

  final int score;
  final double survivedSeconds;
  final VoidCallback onRetry;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Positioned.fill(
      child: Container(
        color: Colors.black.withValues(alpha: 0.54),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 360),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  color: const Color(0xFF111827).withValues(alpha: 0.92),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.redAccent.withValues(alpha: 0.4),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.redAccent.withValues(alpha: 0.16),
                      blurRadius: 24,
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'GAME OVER',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        color: Colors.redAccent,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.6,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _ResultMetric(label: 'SCORE', value: score.toString()),
                        const SizedBox(width: 18),
                        _ResultMetric(
                          label: 'TIME',
                          value: _formatDuration(survivedSeconds),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        FilledButton.icon(
                          onPressed: onRetry,
                          icon: const Icon(Icons.replay),
                          label: const Text('Retry'),
                        ),
                        const SizedBox(width: 12),
                        OutlinedButton.icon(
                          onPressed: onBack,
                          icon: const Icon(Icons.arrow_back),
                          label: const Text('Room'),
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
    );
  }
}

class _ResultMetric extends StatelessWidget {
  const _ResultMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SizedBox(
      width: 120,
      child: Column(
        children: [
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: Colors.white.withValues(alpha: 0.5),
              fontWeight: FontWeight.w800,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: theme.textTheme.headlineSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
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
        color: const Color(0xFF1F2937).withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: theme.textTheme.labelSmall?.copyWith(
              color: color.withValues(alpha: 0.7),
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
          ),
          Text(
            value,
            style: theme.textTheme.headlineLarge?.copyWith(
              color: color,
              fontWeight: FontWeight.w900,
              shadows: [
                Shadow(color: color.withValues(alpha: 0.5), blurRadius: 8),
              ],
            ),
          ),
          Text(
            subtitle,
            style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey),
          ),
        ],
      ),
    );
  }
}
