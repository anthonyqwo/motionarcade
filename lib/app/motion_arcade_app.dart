import 'package:flutter/material.dart';

import '../controller/controller_home_page.dart';
import '../desktop/desktop_home_page.dart';
import 'app_mode.dart';
import 'motion_arcade_theme.dart';

class MotionArcadeApp extends StatelessWidget {
  const MotionArcadeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Motion Arcade',
      debugShowCheckedModeBanner: false,
      theme: MotionArcadeTheme.light(),
      home: const ModeSelectPage(),
    );
  }
}

class ModeSelectPage extends StatelessWidget {
  const ModeSelectPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 720;

            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 980),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _Header(isWide: isWide),
                      const SizedBox(height: 28),
                      Expanded(
                        child: isWide
                            ? Row(
                                children: const [
                                  Expanded(
                                    child: _ModeCard(mode: AppMode.desktop),
                                  ),
                                  SizedBox(width: 16),
                                  Expanded(
                                    child: _ModeCard(mode: AppMode.controller),
                                  ),
                                ],
                              )
                            : ListView(
                                children: const [
                                  _ModeCard(mode: AppMode.desktop),
                                  SizedBox(height: 16),
                                  _ModeCard(mode: AppMode.controller),
                                ],
                              ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Phase 0 build: app mode routing, base pages, and shared models.',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.isWide});

  final bool isWide;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: isWide
          ? CrossAxisAlignment.start
          : CrossAxisAlignment.center,
      children: [
        Text(
          'Motion Arcade',
          textAlign: isWide ? TextAlign.left : TextAlign.center,
          style: theme.textTheme.displaySmall?.copyWith(
            color: theme.colorScheme.onSurface,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Use a phone as a motion controller and a desktop as the game screen.',
          textAlign: isWide ? TextAlign.left : TextAlign.center,
          style: theme.textTheme.titleMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _ModeCard extends StatelessWidget {
  const _ModeCard({required this.mode});

  final AppMode mode;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDesktop = mode == AppMode.desktop;

    return FilledButton.tonalIcon(
      style: FilledButton.styleFrom(
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.all(24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      icon: Icon(
        isDesktop ? Icons.desktop_windows_outlined : Icons.sensors_outlined,
      ),
      label: SizedBox(
        width: double.infinity,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              mode.title,
              style: theme.textTheme.headlineSmall?.copyWith(
                color: theme.colorScheme.onSecondaryContainer,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              mode.subtitle,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSecondaryContainer,
              ),
            ),
            const SizedBox(height: 22),
            Row(
              children: [
                Text(isDesktop ? 'Open room host' : 'Open controller'),
                const SizedBox(width: 8),
                const Icon(Icons.arrow_forward, size: 18),
              ],
            ),
          ],
        ),
      ),
      onPressed: () {
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => switch (mode) {
              AppMode.desktop => const DesktopHomePage(),
              AppMode.controller => const ControllerHomePage(),
            },
          ),
        );
      },
    );
  }
}
