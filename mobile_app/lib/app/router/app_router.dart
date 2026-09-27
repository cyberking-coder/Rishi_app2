import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show Supabase;

import '../../features/auth/application/auth_providers.dart';
import '../../features/auth/presentation/screens/forgot_password_screen.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/signup_screen.dart';
import '../../features/auth/presentation/screens/splash_screen.dart';
import '../../features/audio/presentation/screens/now_playing_screen.dart';
import '../../core/config/purchase_config.dart';
import '../../features/chat/presentation/screens/chat_screen.dart';
import '../../features/downloads/presentation/screens/downloads_screen.dart';
import '../../features/downloads/presentation/screens/offline_player_screen.dart';
import '../../features/home/presentation/screens/home_screen.dart';
import '../../features/home/presentation/screens/browse_screen.dart';
import '../../features/lms/domain/entities/lesson.dart';
import '../../features/lms/presentation/screens/course_detail_screen.dart';
import '../../features/lms/presentation/screens/courses_screen.dart';
import '../../features/help_support/domain/entities/help_entities.dart';
import '../../features/help_support/presentation/screens/contact_support_screen.dart';
import '../../features/help_support/presentation/screens/feedback_screen.dart';
import '../../features/help_support/presentation/screens/help_support_screen.dart';
import '../../features/help_support/presentation/screens/support_requests_screen.dart';
import '../../features/help_support/presentation/screens/support_ticket_screen.dart';
import '../../features/lms/presentation/screens/payment_success_screen.dart';
import '../../features/lms/presentation/screens/text_lesson_screen.dart';
import '../../features/lms/presentation/screens/video_lesson_screen.dart';
import '../../features/profile/presentation/screens/profile_screen.dart';
import '../../features/audio/presentation/screens/audio_link_screen.dart';
import '../../features/watch/presentation/screens/watch_screen.dart';
import '../widgets/app_shell.dart';

final goRouterProvider = Provider<GoRouter>((ref) {
  // IMPORTANT: do NOT `ref.watch` auth (or the login flag) in this provider
  // body. Watching rebuilds this provider on every auth-stream emission —
  // and AppUser has no ==, so every event (a ~hourly token refresh, an app
  // resume, an offline refresh attempt) counts as a change. That built a
  // brand-new GoRouter each time, which MaterialApp.router reinitialises from
  // initialLocation (/splash -> /home), throwing away the navigation stack —
  // i.e. it bounced a user deep in the app back to Home mid-session. The
  // router instance must be STABLE; re-evaluation is driven by
  // refreshListenable below, and the redirect reads the CURRENT auth/flag with
  // ref.read each time it runs.
  return GoRouter(
    initialLocation: '/splash',
    refreshListenable: GoRouterRefreshStream(ref),
    redirect: (context, state) {
      // The splash screen owns its own navigation (after a short delay) and
      // must never be redirected away mid-animation.
      if (state.matchedLocation == '/splash') return null;

      // Read (not watch) the current auth value each time the redirect runs;
      // GoRouterRefreshStream re-runs it whenever auth or the login flag moves.
      final authState = ref.read(authStateChangesProvider);

      // A still-resolving auth stream is NOT a sign-out. Treating the
      // transient null (while the stream re-subscribes, or after a relaunch)
      // as logged-out is what bounced a signed-in user to /login — which is
      // how tapping something like the account link could look like it
      // logged you out. Only decide once there is a real value; until then,
      // leave navigation where it is.
      if (authState.isLoading) return null;

      // Signed-in is decided from THREE signals, any of which is enough, so an
      // offline token expiry can never bounce a user to /login (and on to
      // /home) mid-use — e.g. while playing a downloaded track:
      //   1. the live auth stream has a user, or
      //   2. Supabase still holds a persisted session, or
      //   3. our own durable login flag is set.
      // (1) and (2) both come from Supabase, and on iOS gotrue was observed to
      // DROP the persisted session after the short access token expires while
      // offline — which is why +46 (fall back to currentUser) and a
      // currentSession-only check were not enough. (3) is app-owned: set the
      // moment a real session is seen and cleared only on an explicit
      // sign-out, so it survives gotrue dropping its session offline. A real
      // logout clears all three, so signing out still works.
      final isLoggedIn = authState.valueOrNull != null ||
          Supabase.instance.client.auth.currentSession != null ||
          ref.read(loginFlagProvider);
      final isAuthRoute = state.matchedLocation == '/login' ||
          state.matchedLocation == '/forgot-password' ||
          state.matchedLocation == '/signup';

      if (!isLoggedIn && !isAuthRoute) return '/login';
      if (isLoggedIn && isAuthRoute) return '/home';
      return null;
    },
    routes: [
      GoRoute(path: '/splash', builder: (_, __) => const SplashScreen()),
      // Deep link target: meditationapp://app/payment-success?course_id=…
      // A custom-scheme link's HOST is not part of the path, so the
      // destination has to live in the path ("app" is the host) — an
      // earlier meditationapp://payment-success?... resolved to "/" and
      // hit "no routes for location".
      GoRoute(
        path: '/payment-success',
        builder: (_, state) => PaymentSuccessScreen(
          courseId: state.uri.queryParameters['course_id'],
        ),
      ),
      // Safety net for a bare meditationapp://app link, which lands here
      // rather than on a real screen.
      GoRoute(path: '/', redirect: (_, __) => '/home'),
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      GoRoute(
        path: '/forgot-password',
        builder: (_, __) => const ForgotPasswordScreen(),
      ),
      GoRoute(path: '/signup', builder: (_, __) => const SignupScreen()),
      // The four bottom-nav tabs use NoTransitionPage: tapping a tab should
      // read as the same shell swapping its body, not as a page sliding in
      // from the side ("page turning"). The default platform page animates a
      // horizontal slide, which is wrong for peer tabs that replace each
      // other. Drill-down routes (a lesson, a course) keep the default slide.
      GoRoute(
        path: '/home',
        pageBuilder: (_, __) => const NoTransitionPage(
          child: AppShell(tab: AppTab.home, child: HomeScreen()),
        ),
      ),
      GoRoute(
        path: '/now-playing',
        builder: (_, __) => const NowPlayingScreen(),
      ),
      GoRoute(
        path: '/downloads',
        pageBuilder: (_, __) => const NoTransitionPage(
          child: AppShell(tab: AppTab.downloads, child: DownloadsScreen()),
        ),
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
        pageBuilder: (_, __) => const NoTransitionPage(
          child: AppShell(tab: AppTab.profile, child: ProfileScreen()),
        ),
      ),
      GoRoute(
        path: '/courses',
        pageBuilder: (_, __) => const NoTransitionPage(
          child: AppShell(tab: AppTab.courses, child: CoursesScreen()),
        ),
      ),
      GoRoute(
        path: '/course/:id',
        builder: (_, state) => CourseDetailScreen(
          courseId: state.pathParameters['id']!,
          title: state.extra as String? ?? 'Course',
        ),
      ),
      GoRoute(
        path: '/lesson-video/:id',
        builder: (_, state) =>
            VideoLessonScreen(lesson: state.extra as Lesson),
      ),
      GoRoute(
        path: '/lesson-text/:id',
        builder: (_, state) =>
            TextLessonScreen(lesson: state.extra as Lesson),
      ),
      // ── Help & Support ──
      // Not wrapped in AppShell. Help is a drill-down from Settings, and
      // several of these screens have a keyboard open — a bottom nav
      // under one leaves the composer fighting for the last 60 pixels.
      GoRoute(
        path: '/help-support',
        builder: (_, __) => const HelpSupportScreen(),
      ),
      GoRoute(
        path: '/help-support/contact',
        // `extra` is optional here, unlike the lesson routes: this screen
        // is reachable both from a category (which preselects one) and
        // from the plain Contact button (which does not).
        builder: (_, state) =>
            ContactSupportScreen(args: state.extra as ContactArgs?),
      ),
      GoRoute(
        path: '/help-support/feedback',
        builder: (_, __) => const FeedbackScreen(),
      ),
      GoRoute(
        path: '/help-support/requests',
        builder: (_, __) => const SupportRequestsScreen(),
      ),
      GoRoute(
        path: '/help-support/requests/:id',
        // The ticket is passed when arriving from the list so the header
        // renders at once, but the id is the source of truth — a cold
        // deep link has no extra, and the screen handles that.
        builder: (_, state) => SupportTicketScreen(
          ticketId: state.pathParameters['id']!,
          ticket: state.extra as SupportTicket?,
        ),
      ),
      GoRoute(path: '/watch', builder: (_, __) => const WatchScreen()),
      // Not wrapped in AppShell: the guide is a drill-down from Home,
      // and a bottom nav under an open keyboard would leave the composer
      // fighting for the last 60 pixels of the screen.
      GoRoute(
        path: '/chat',
        // Redirected away rather than removed. Hiding the button on Home
        // is not enough on its own: a notification deep link, a saved
        // route, or a restored session could still land here, and a
        // reviewer following any of those would find the feature the
        // build is meant not to have. The route stays so nothing crashes
        // on an unknown path; it simply goes nowhere on iOS.
        redirect: (_, __) => kGuideEnabled ? null : '/home',
        builder: (_, __) => const ChatScreen(),
      ),
      // Where a "start your day" notification lands. Takes only an id,
      // because a notification payload is strings and nothing else — no
      // `extra` object to lean on, unlike every route above.
      GoRoute(
        path: '/audio/:id',
        builder: (_, state) =>
            AudioLinkScreen(audioId: state.pathParameters['id']!),
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
    // Re-run the redirect on an auth change OR when the app-owned login flag
    // flips (login / logout / account deletion). The redirect reads both with
    // ref.read, so it needs a notify to re-evaluate — without listening to the
    // flag, a login/logout would not re-gate navigation. This only re-runs the
    // redirect; it does NOT rebuild the GoRouter, so the navigation stack is
    // preserved (see the note in goRouterProvider).
    ref.listen(authStateChangesProvider, (_, __) => notifyListeners());
    ref.listen(loginFlagProvider, (_, __) => notifyListeners());
  }
}
