import 'package:flutter/material.dart';

import '../../features/audio/presentation/widgets/mini_player.dart';

/// Wraps a screen with the persistent audio mini player pinned to the
/// bottom, so background playback stays visible while browsing.
class AppShell extends StatelessWidget {
  final Widget child;

  const AppShell({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Expanded(child: child),
          const MiniPlayer(),
        ],
      ),
    );
  }
}
