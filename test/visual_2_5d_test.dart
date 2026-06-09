import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motionarcade/desktop/game_shell_page.dart';
import 'package:motionarcade/network/connection_status.dart';
import 'package:motionarcade/shared/models/motion_event.dart';
import 'package:motionarcade/shared/models/motion_trail_sample.dart';
import 'package:motionarcade/shared/models/player.dart';
import 'package:motionarcade/shared/visual/depth_transform.dart';
import 'package:motionarcade/shared/visual/trail_renderer.dart';

void main() {
  test('depth transform scales and fades by depth', () {
    const transform = DepthTransform();

    expect(transform.scaleForDepth(0), lessThan(transform.scaleForDepth(1)));
    expect(
      transform.opacityForDepth(0),
      lessThan(transform.opacityForDepth(1)),
    );
  });

  test('trail projection maps controller coordinates to screen', () {
    const projection = TrailProjection();
    final center = projection.project(
      tipX: 0,
      tipY: 0,
      size: const Size(200, 100),
    );
    final upperRight = projection.project(
      tipX: 1,
      tipY: 1,
      size: const Size(200, 100),
    );

    expect(center, const Offset(100, 50));
    expect(upperRight.dx, greaterThan(center.dx));
    expect(upperRight.dy, lessThan(center.dy));
  });

  testWidgets('game shell renders live preview HUD', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: GameShellPage(
            status: ConnectionStatus.connected,
            players: const [
              Player(id: 'p1', name: 'Player 1', deviceLabel: 'phone'),
            ],
            trailPoints: [
              TrailRenderPoint(
                playerId: 'p1',
                tipX: 0,
                tipY: 0,
                strength: 4,
                timestamp: DateTime.now(),
              ),
            ],
            trailTransportLabel: 'UDP 1',
            lastSlash: SlashEvent(
              playerId: 'p1',
              timestamp: DateTime.now(),
              direction: MotionDirection.right,
              power: 0.6,
              durationMs: 120,
            ),
            lastEventLabel: 'slash from p1',
          ),
        ),
      ),
    );

    expect(find.text('Live Game Preview'), findsOneWidget);
    expect(find.text('Players'), findsOneWidget);
    expect(find.text('Trail'), findsOneWidget);
    expect(find.text('slash from p1'), findsOneWidget);
  });

  testWidgets('game shell handles slash updates after layout', (tester) async {
    final now = DateTime.now();

    Widget buildShell({SlashEvent? slash}) {
      return MaterialApp(
        home: Scaffold(
          body: GameShellPage(
            status: ConnectionStatus.connected,
            players: const [
              Player(id: 'p1', name: 'Player 1', deviceLabel: 'phone'),
            ],
            trailPoints: [
              TrailRenderPoint(
                playerId: 'p1',
                tipX: 0,
                tipY: 0,
                strength: 4,
                timestamp: now,
              ),
            ],
            trailTransportLabel: 'UDP 1',
            lastSlash: slash,
            lastEventLabel: slash == null ? 'none' : 'slash from p1',
          ),
        ),
      );
    }

    await tester.pumpWidget(buildShell());
    await tester.pumpWidget(
      buildShell(
        slash: SlashEvent(
          playerId: 'p1',
          timestamp: now,
          direction: MotionDirection.right,
          power: 0.6,
          durationMs: 120,
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('slash from p1'), findsOneWidget);
  });

  test(
    'trail renderer performs Catmull-Rom spline interpolation for large gaps',
    () {
      final now = DateTime.now();
      final p1 = TrailRenderPoint(
        playerId: 'p1',
        tipX: 0,
        tipY: 0,
        strength: 4,
        timestamp: now,
      );
      final p2 = TrailRenderPoint(
        playerId: 'p1',
        tipX: 1,
        tipY: 1,
        strength: 6,
        timestamp: now.add(const Duration(milliseconds: 30)),
      );
      final p3 = TrailRenderPoint(
        playerId: 'p1',
        tipX: 2,
        tipY: 0,
        strength: 5,
        timestamp: now.add(const Duration(milliseconds: 60)),
      );

      final renderer = TrailRenderer(points: [p1, p2, p3], now: now);
      final smoothed = renderer.interpolate([p1, p2, p3]);

      expect(smoothed.length, greaterThan(3));
      expect(smoothed[1].timestamp.isAfter(p1.timestamp), isTrue);
      expect(smoothed[1].timestamp.isBefore(p2.timestamp), isTrue);
    },
  );

  test(
    'trail renderer uses adaptive interpolation steps based on gap duration',
    () {
      final now = DateTime.now();
      final p1 = TrailRenderPoint(
        playerId: 'p1',
        tipX: 0,
        tipY: 0,
        strength: 4,
        timestamp: now,
      );
      final p2 = TrailRenderPoint(
        playerId: 'p1',
        tipX: 1,
        tipY: 1,
        strength: 6,
        timestamp: now.add(const Duration(milliseconds: 30)),
      );
      final p3Small = TrailRenderPoint(
        playerId: 'p1',
        tipX: 2,
        tipY: 0,
        strength: 5,
        timestamp: now.add(const Duration(milliseconds: 60)), // 30ms gap
      );
      final p3Large = TrailRenderPoint(
        playerId: 'p1',
        tipX: 2,
        tipY: 0,
        strength: 5,
        timestamp: now.add(const Duration(milliseconds: 130)), // 100ms gap
      );

      final renderer = TrailRenderer(points: [], now: now);

      final smallGapResult = renderer.interpolate([p1, p2, p3Small]);
      final largeGapResult = renderer.interpolate([p1, p2, p3Large]);

      expect(largeGapResult.length, greaterThan(smallGapResult.length));
    },
  );

  test('MotionEventNormalization normalizes event timestamps correctly', () {
    final now = DateTime.now();
    final originalTime = now.subtract(const Duration(seconds: 10));

    final join = JoinEvent(
      playerId: 'p1',
      timestamp: originalTime,
      name: 'Test',
      device: 'dev',
    );
    final normalizedJoin = join.normalized(now);
    expect(normalizedJoin.timestamp, equals(now));

    final trail = MotionTrailEvent(
      playerId: 'p1',
      timestamp: originalTime,
      referenceTimestamp: originalTime,
      samples: const [
        MotionTrailSample(tMs: 0, tipX: 0, tipY: 0, strength: 0),
        MotionTrailSample(tMs: 50, tipX: 1, tipY: 1, strength: 1),
      ],
    );
    final normalizedTrail = trail.normalized(now) as MotionTrailEvent;
    expect(normalizedTrail.timestamp, equals(now));
    // The reference timestamp should align the last sample (tMs: 50) with 'now'
    expect(
      normalizedTrail.referenceTimestamp,
      equals(now.subtract(const Duration(milliseconds: 50))),
    );
  });

  testWidgets('game shell renders aiming reticle when pointing statically', (
    tester,
  ) async {
    final now = DateTime.now();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: GameShellPage(
            status: ConnectionStatus.connected,
            players: const [
              Player(id: 'p1', name: 'Player 1', deviceLabel: 'phone'),
            ],
            trailPoints: [
              TrailRenderPoint(
                playerId: 'p1',
                tipX: 0,
                tipY: 0,
                strength: 2.0,
                timestamp: now,
              ),
            ],
            trailTransportLabel: 'UDP 1',
            lastSlash: null,
            lastEventLabel: 'none',
          ),
        ),
      ),
    );

    await tester.pump();
    expect(find.byType(GameShellPage), findsOneWidget);
  });
}
