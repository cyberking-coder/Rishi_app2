import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/application/auth_providers.dart';
import '../../features/auth/presentation/screens/forgot_password_screen.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/audio/presentation/screens/now_playing_screen.dart';
import '../../features/downloads/presentation/screens/downloads_screen.dart';
import '../../features/downloads/presentation/screens/offline_player_screen.dart';
import '../../features/home/presentation/screens/home_screen.dart';
import '../../features/player/presentation/screens/video_player_screen.dart';
import '../../features/profile/presentation/screens/profile_screen.dart';
import '../widgets/app_shell.dart';

final goRouterProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateChangesProvider);

  return GoRouter(
    initialLocation: '/login',
    refreshListenable: GoRouterRefreshStream(ref),
    redirect: (context, state) {
      final isLoggedIn = authState.valueOrNull != null;
      final isAuthRoute = state.matchedLocation == '/login' ||
          state.matchedLocation == '/forgot-password';

      if (!isLoggedIn && !isAuthRoute) return '/login';
      if (isLoggedIn && isAuthRoute) return '/home';
      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      GoRoute(
        path: '/forgot-password',
        builder: (_, __) => const ForgotPasswordScreen(),
      ),
      GoRoute(
        path: '/home',
        builder: (_, __) => const AppShell(child: HomeScreen()),
      ),
      GoRoute(
        path: '/player/:videoId',
        builder: (_, state) => VideoPlayerScreen(
          videoId: state.pathParameters['videoId']!,
        ),
      ),
      GoRoute(
        path: '/now-playing',
        builder: (_, __) => const NowPlayingScreen(),
      ),
      GoRoute(
        path: '/downloads',
        builder: (_, __) => const AppShell(child: DownloadsScreen()),
      ),
      GoRoute(
        path: '/offline-player/:contentId',
        builder: (_, state) => OfflinePlayerScreen(
          contentId: state.pathParameters['contentId']!,
          title: state.extra as String? ?? 'Offline',
        ),
      ),
      GoRoute(
        path: '/profile',
        builder: (_, __) => const AppShell(child: ProfileScreen()),
      ),
    ],
  );
});

/// Bridges Riverpod's authStateChangesProvider into a Listenable so
/// GoRouter re-evaluates `redirect` whenever the Supabase session changes.
class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Ref ref) {
    ref.listen(authStateChangesProvider, (_, __) => notifyListeners());
  }
}
