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
  Duration _lastElapsed = Duration.zero;

  final ScreenShakeController _shakeController = ScreenShakeController();
  final List<Particle> _particles = [];
  SlashEvent? _lastSlashSeen;
  final ValueNotifier<DateTime> _frameClock = ValueNotifier<DateTime>(
    DateTime.now(),
  );
  Size _arenaSize = const Size(800, 450);

  @override
  void initState() {
    super.initState();
    _state = SaberGameState(
      server: widget.server,
      initialPlayers: widget.players,
      motionEvents: widget.motionEvents,
    );
    _state.addListener(_onStateChange);

    _ticker = createTicker((elapsed) {
      final dt =
          (elapsed.inMicroseconds - _lastElapsed.inMicroseconds) / 1000000.0;
      _lastElapsed = elapsed;

      _state.update(dt);
      final now = DateTime.now();
      _particles.removeWhere((p) => !p.isAlive(now));
      _frameClock.value = now;
    });
    _ticker.start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _state.removeListener(_onStateChange);
    _state.dispose();
    _frameClock.dispose();
    super.dispose();
  }

  void _onStateChange() {
    if (_state.lastSlash != _lastSlashSeen && _state.lastSlash != null) {
      _lastSlashSeen = _state.lastSlash;

      _shakeController.trigger(
        intensity: 8.0 + _lastSlashSeen!.power * 12.0,
        duration: const Duration(milliseconds: 250),
      );

      final origin = const TrailImpactLocator().locate(
        slash: _lastSlashSeen!,
        points: _state.trailPoints,
        size: _arenaSize,
      );

      final isForward = _lastSlashSeen!.direction == MotionDirection.forward;
      final color = isForward
          ? const Color(0xFF22C55E)
          : const Color(0xFFFF4EBD);

      final burst = const ParticleBurstFactory().createBurst(
        origin: origin,
        now: DateTime.now(),
        color: color,
        count: 24,
        speed: 55.0 + _lastSlashSeen!.power * 35.0,
      );
      _particles.addAll(burst);
      _frameClock.value = DateTime.now();
    }
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

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
                    label: 'SCORE',
                    value: _state.scoring.score.toString(),
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
                        return CustomPaint(
                          painter: SaberPainter(
                            targets: _state.targets,
                            trailPoints: _state.trailPoints,
                            frameClock: _frameClock,
                            lastSlash: _state.lastSlash,
                            shakeController: _shakeController,
                            particles: _particles,
                          ),
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
                      value: _state.scoring.combo.toString(),
                      subtitle: 'Max Combo: ${_state.scoring.maxCombo}',
                      color: Colors.orangeAccent,
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Multiplier Card
                  Expanded(
                    flex: 2,
                    child: _InfoCard(
                      title: 'MULTIPLIER',
                      value: 'x${_state.scoring.multiplier.toStringAsFixed(1)}',
                      subtitle: 'Hit blocks to build multiplier',
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
                            'CONTROLLER STATUS',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: Colors.grey,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.2,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Expanded(
                            child: _state.players.isEmpty
                                ? const Center(
                                    child: Text(
                                      'No players connected',
                                      style: TextStyle(color: Colors.grey),
                                    ),
                                  )
                                : ListView.builder(
                                    itemCount: _state.players.length,
                                    itemBuilder: (context, index) {
                                      final player = _state.players[index];
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
                                          Text(
                                            player.name,
                                            style: TextStyle(
                                              color: isDisconnected
                                                  ? Colors.grey
                                                  : Colors.white,
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
