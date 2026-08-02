import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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
    return Container(
      decoration: BoxDecoration(
        gradient: AppTheme.clayFill(),
        boxShadow: AppTheme.navShadow,
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 62,
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
                icon: Icons.school_outlined,
                activeIcon: Icons.school_rounded,
                label: 'Courses',
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
    final color = selected ? AppTheme.sage : AppTheme.textSecondary;

    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.radiusRow),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(selected ? activeIcon : icon, size: 23, color: color),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: 10.5,
                color: color,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
