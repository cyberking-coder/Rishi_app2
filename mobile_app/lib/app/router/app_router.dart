import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/application/auth_providers.dart';
import '../../features/auth/presentation/screens/forgot_password_screen.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/signup_screen.dart';
import '../../features/auth/presentation/screens/splash_screen.dart';
import '../../features/audio/presentation/screens/now_playing_screen.dart';
import '../../features/downloads/presentation/screens/downloads_screen.dart';
import '../../features/downloads/presentation/screens/offline_player_screen.dart';
import '../../features/home/presentation/screens/home_screen.dart';
import '../../features/home/presentation/screens/browse_screen.dart';
import '../../features/lms/domain/entities/lesson.dart';
import '../../features/lms/presentation/screens/course_detail_screen.dart';
import '../../features/lms/presentation/screens/courses_screen.dart';
import '../../features/lms/presentation/screens/text_lesson_screen.dart';
import '../../features/profile/presentation/screens/profile_screen.dart';
import '../widgets/app_shell.dart';

final goRouterProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateChangesProvider);

  return GoRouter(
    initialLocation: '/splash',
    refreshListenable: GoRouterRefreshStream(ref),
    redirect: (context, state) {
      // The splash screen owns its own navigation (after a short delay) and
      // must never be redirected away mid-animation.
      if (state.matchedLocation == '/splash') return null;

      final isLoggedIn = authState.valueOrNull != null;
      final isAuthRoute = state.matchedLocation == '/login' ||
          state.matchedLocation == '/forgot-password' ||
          state.matchedLocation == '/signup';

      if (!isLoggedIn && !isAuthRoute) return '/login';
      if (isLoggedIn && isAuthRoute) return '/home';
      return null;
    },
    routes: [
      GoRoute(path: '/splash', builder: (_, __) => const SplashScreen()),
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      GoRoute(
        path: '/forgot-password',
        builder: (_, __) => const ForgotPasswordScreen(),
      ),
      GoRoute(path: '/signup', builder: (_, __) => const SignupScreen()),
      GoRoute(
        path: '/home',
        builder: (_, __) => const AppShell(child: HomeScreen()),
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
      GoRoute(path: '/courses', builder: (_, __) => const CoursesScreen()),
      GoRoute(
        path: '/course/:id',
        builder: (_, state) => CourseDetailScreen(
          courseId: state.pathParameters['id']!,
          title: state.extra as String? ?? 'Course',
        ),
      ),
      GoRoute(
        path: '/lesson-text/:id',
        builder: (_, state) =>
            TextLessonScreen(lesson: state.extra as Lesson),
      ),
      GoRoute(
        path: '/search',
        builder: (_, __) => const BrowseScreen(title: 'Search'),
      ),
      GoRoute(
        path: '/category/:id',
        builder: (_, state) => BrowseScreen(
          categoryId: state.pathParameters['id'],
          title: state.extra as String? ?? 'Category',
        ),
      ),
    ],
  );
});

class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Ref ref) {
    ref.listen(authStateChangesProvider, (_, __) => notifyListeners());
  }
}
