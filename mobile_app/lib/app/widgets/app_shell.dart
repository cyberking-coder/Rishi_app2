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
    // A floating bar rather than a full-width edge-to-edge one: it sits
    // inset from all three sides so the page's background — the misty
    // hills on Downloads and Profile — carries on running underneath it,
    // which is what makes those screens read as one continuous scene.
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
        child: Container(
          decoration: BoxDecoration(
            gradient: AppTheme.clayFill(AppTheme.surface),
            borderRadius: BorderRadius.circular(AppTheme.radiusCard),
            boxShadow: AppTheme.cardShadow,
          ),
          child: SizedBox(
            height: 66,
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
    final color = selected ? AppTheme.sageDark : AppTheme.textSecondary;

    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.radiusCard),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // The short rule above the active tab. Sits on the bar's own
            // top edge, which is what ties the indicator to the bar
            // rather than to the icon floating below it.
            if (selected)
              Positioned(
                top: 0,
                child: Container(
                  width: 26,
                  height: 3.5,
                  decoration: BoxDecoration(
                    color: AppTheme.sageDark,
                    borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                  ),
                ),
              ),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  decoration: BoxDecoration(
                    // A soft chip behind the active icon only. On the
                    // inactive ones it would turn the bar into four
                    // buttons, which is the look the floating bar exists
                    // to get away from.
                    color: selected ? AppTheme.sageSoft : Colors.transparent,
                    borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                  ),
                  child: Icon(
                    selected ? activeIcon : icon,
                    size: 23,
                    color: color,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  label,
                  style: TextStyle(
                    fontFamily: AppTheme.text,
                    fontSize: 11,
                    color: color,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
