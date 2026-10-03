import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/application/app_access_controller.dart';
import '../../features/auth/domain/entities/app_access_mode.dart';
import '../../features/auth/presentation/screens/forgot_password_screen.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/signup_screen.dart';
import '../../features/auth/presentation/screens/splash_screen.dart';
import '../../features/audio/presentation/screens/now_playing_screen.dart';
import '../../core/config/purchase_config.dart';
import '../../features/chat/presentation/screens/chat_screen.dart';
import '../../features/downloads/presentation/screens/downloads_screen.dart';
import '../../features/downloads/presentation/screens/offline_hub_screen.dart';
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

/// Locations an [AppAccessMode.authenticatedOffline] user may reach: the
/// Offline Hub, their Downloads list, and the encrypted offline player.
/// Everything else routes to the hub while offline.
bool _offlineAllowed(String loc) =>
    loc == '/offline' ||
    loc == '/downloads' ||
    loc.startsWith('/offline-player');

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

      // ONE source of truth: the access-mode controller. Splash, profile and
      // the router used to each decide "logged in?" differently, which is how
      // a reinstall could land inside the app with no real session. Now the
      // controller resolves a single AppAccessMode and the router just obeys.
      final mode = ref.read(appAccessModeProvider);

      // Still resolving (first frames after launch): leave navigation where
      // it is — a transient unknown is never a sign-out.
      if (mode == AppAccessMode.resolving) return null;

      final loc = state.matchedLocation;
      final isAuthRoute =
          loc == '/login' || loc == '/forgot-password' || loc == '/signup';

      switch (mode) {
        case AppAccessMode.resolving:
          return null; // handled above, kept for exhaustiveness
        case AppAccessMode.signedOut:
          return isAuthRoute ? null : '/login';
        case AppAccessMode.authenticatedOffline:
          // Only downloaded/cached content is reachable offline; everything
          // else goes to the Offline Hub instead of failing network calls.
          return _offlineAllowed(loc) ? null : '/offline';
        case AppAccessMode.authenticatedOnline:
          // Back online: never strand the user on an auth screen or the hub.
          if (isAuthRoute || loc == '/offline') return '/home';
          return null;
      }
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
      // Landing screen while in authenticatedOffline mode (see the redirect).
      GoRoute(path: '/offline', builder: (_, __) => const OfflineHubScreen()),
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
        // A lesson is opened only via launchLesson, which passes the Lesson in
        // `extra`. A cold deep link or state restoration has no extra, and
        // `state.extra as Lesson` would then crash the router builder on
        // `null as Lesson`. Redirect to the catalogue instead; the cast below
        // is safe once this guard has run.
        redirect: (_, state) => state.extra is Lesson ? null : '/courses',
        builder: (_, state) =>
            VideoLessonScreen(lesson: state.extra as Lesson),
      ),
      GoRoute(
        path: '/lesson-text/:id',
        redirect: (_, state) => state.extra is Lesson ? null : '/courses',
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
    // Re-run the redirect whenever the single access mode changes
    // (resolving → online/offline/signedOut, a login, a logout, a
    // server-side sign-out). This only re-runs the redirect; it does NOT
    // rebuild the GoRouter, so the navigation stack is preserved (see the
    // note in goRouterProvider).
    ref.listen(appAccessModeProvider, (_, __) => notifyListeners());
  }
}
