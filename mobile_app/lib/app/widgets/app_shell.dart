import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/config/purchase_config.dart';
import '../theme/app_theme.dart';
import '../../features/audio/presentation/widgets/mini_player.dart';
import '../../features/live/application/live_providers.dart';

/// One of the app's four top-level destinations. Courses is a peer of
/// Home rather than a row buried inside it — learning is its own mode of
/// using the app, not a shelf on the listening screen.
enum AppTab { home, courses, downloads, profile }

const _tabRoutes = {
  AppTab.home: '/home',
  AppTab.courses: '/courses',
  AppTab.downloads: '/downloads',
  AppTab.profile: '/profile',
};

/// Wraps a top-level screen with the persistent mini player and bottom
/// navigation. Screens pushed on top (now playing, a lesson, a category)
/// deliberately don't use this — they're a drill-down, and keeping the
/// nav visible there would invite tapping "Home" mid-lesson.
class AppShell extends ConsumerWidget {
  final Widget child;
  final AppTab tab;

  const AppShell({super.key, required this.child, required this.tab});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Registering for reminders hangs off the shell because the shell is
    // exactly "a signed-in user is looking at the app" — which is both
    // when a token is obtainable and when asking for notification
    // permission makes sense. Doing it in main() would ask before the
    // login screen, with no context for why.
    ref.watch(pushRegistrationProvider);

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Column(
        children: [
          Expanded(child: child),
          const MiniPlayer(),
          _BottomNav(current: tab),
        ],
      ),
    );
  }
}

class _BottomNav extends StatelessWidget {
  final AppTab current;

  const _BottomNav({required this.current});

  @override
  Widget build(BuildContext context) {
    // Edge to edge, replacing the floating pill: the design puts the bar
    // on the page's own edge rather than hovering it inside a card.
    //
    // Deliberately NOT a BackdropFilter. The shell lays this out in a
    // Column below the page, so nothing is behind the bar to blur — a
    // filter here would cost a full-screen blur every frame and show
    // nothing for it. Real glass needs the shell to become a Stack with
    // the page running underneath, which means giving every screen
    // bottom padding so its last row is not hidden. That is a change
    // worth making on its own rather than smuggled into a restyle.
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: Color(0xFAFAF8FF),
        border: Border(
          top: BorderSide(color: AppTheme.border, width: 0.5),
        ),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 56,
          child: Row(
            children: [
              _NavItem(
                icon: Icons.home_outlined,
                activeIcon: Icons.home_rounded,
                label: 'Home',
                selected: current == AppTab.home,
                onTap: () => _go(context, AppTab.home),
              ),
              _NavItem(
                // A graduation cap is a literal education signal sitting
                // in the navigation bar, which is the first thing a
                // reviewer sees and the last place to leave one.
                icon: kEducationFramingEnabled
                    ? Icons.school_outlined
                    : Icons.video_library_outlined,
                activeIcon: kEducationFramingEnabled
                    ? Icons.school_rounded
                    : Icons.video_library_rounded,
                label: kEducationFramingEnabled ? 'Courses' : 'Videos',
                selected: current == AppTab.courses,
                onTap: () => _go(context, AppTab.courses),
              ),
              _NavItem(
                icon: Icons.download_outlined,
                activeIcon: Icons.download_rounded,
                label: 'Downloads',
                selected: current == AppTab.downloads,
                onTap: () => _go(context, AppTab.downloads),
              ),
              _NavItem(
                icon: Icons.person_outline_rounded,
                activeIcon: Icons.person_rounded,
                label: 'Profile',
                  selected: current == AppTab.profile,
                  onTap: () => _go(context, AppTab.profile),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _go(BuildContext context, AppTab tab) {
    if (tab == current) return;
    // go() rather than push(): tabs replace each other, so the back
    // button never walks backwards through a tab history.
    context.go(_tabRoutes[tab]!);
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // Colour alone carries the active state now — no chip behind the
    // icon and no rule above it. On a translucent bar both of those read
    // as smudges rather than as indicators, because there is no solid
    // ground for them to sit on.
    final color = selected ? AppTheme.sage : AppTheme.textSecondary;

    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(selected ? activeIcon : icon, size: 23, color: color),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                fontFamily: AppTheme.text,
                fontSize: 10,
                color: color,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
