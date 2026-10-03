// Device-level E2E: the critical user journey, driven as real on-screen taps.
//
//   launch -> (login) -> home -> Courses -> open a course -> open a lesson
//          -> playback appears -> Profile -> logout -> back to login
//
// Boots the actual app (`main()`), so it exercises the real router, auth,
// data loading and player — on a device/emulator, against whatever backend
// the build targets (point the build at STAGING for this).
//
// ---------------------------------------------------------------------------
// RUN (needs a device/emulator + a staging build + a test account):
//   flutter test integration_test/e2e_user_journey_test.dart \
//     --dart-define=E2E_EMAIL=tester@example.com \
//     --dart-define=E2E_PASSWORD='<password>'
// ---------------------------------------------------------------------------
// The account must be able to log in on this device (one-device lock applies).
// If E2E_EMAIL/E2E_PASSWORD are absent the test is skipped (it cannot log in).
// The journey degrades gracefully: if the account has no courses/lessons it
// still verifies login, navigation and logout, and logs what it skipped.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:meditation_app/core/testing/e2e_keys.dart';
import 'package:meditation_app/main.dart' as app;

const _email = String.fromEnvironment('E2E_EMAIL');
const _password = String.fromEnvironment('E2E_PASSWORD');

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('login → course → lesson → playback → logout', (tester) async {
    if (_email.isEmpty || _password.isEmpty) {
      markTestSkipped('Set E2E_EMAIL and E2E_PASSWORD to run the UI journey.');
      return;
    }

    // Boot the real app.
    await app.main();
    await tester.pump(const Duration(seconds: 1));

    // Start from a clean session so the login step is deterministic.
    if (Supabase.instance.client.auth.currentSession != null) {
      await _logoutIfPossible(tester);
    }

    // ── Login ────────────────────────────────────────────────────────────
    await _pumpUntil(tester, find.byKey(E2eKeys.loginEmail));
    await tester.enterText(find.byKey(E2eKeys.loginEmail), _email);
    await tester.enterText(find.byKey(E2eKeys.loginPassword), _password);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.byKey(E2eKeys.loginSubmit));

    // Reaching the shell (the Courses tab exists) proves we're home.
    final reachedHome =
        await _pumpUntil(tester, find.byKey(E2eKeys.navCourses),
            timeout: const Duration(seconds: 25));
    expect(reachedHome, isTrue, reason: 'login did not reach the home shell');

    // ── Courses ──────────────────────────────────────────────────────────
    await tester.tap(find.byKey(E2eKeys.navCourses));
    await tester.pump(const Duration(seconds: 1));

    final courseFinder =
        find.byWidgetPredicate((w) => E2eKeys.isCourseCard(w.key));
    final hasCourse = await _pumpUntil(tester, courseFinder,
        timeout: const Duration(seconds: 20));

    if (!hasCourse) {
      debugPrint('[E2E] No courses visible for this account — '
          'verified login + navigation; skipping lesson/playback.');
    } else {
      await tester.tap(courseFinder.first);
      await tester.pump(const Duration(seconds: 1));

      // ── Open a lesson ───────────────────────────────────────────────────
      final lessonFinder =
          find.byWidgetPredicate((w) => E2eKeys.isLessonTile(w.key));
      final hasLesson = await _pumpUntil(tester, lessonFinder,
          timeout: const Duration(seconds: 20));

      if (hasLesson) {
        await tester.tap(lessonFinder.first);
        await tester.pump(const Duration(seconds: 2));

        // ── Playback appears ───────────────────────────────────────────────
        final hasPlayer = await _pumpUntil(
            tester, find.byKey(E2eKeys.playPause),
            timeout: const Duration(seconds: 25));
        if (hasPlayer) {
          // Toggle play and let it run briefly; the point is that the player
          // mounts and responds without crashing.
          await tester.tap(find.byKey(E2eKeys.playPause));
          await tester.pump(const Duration(seconds: 3));
          expect(find.byKey(E2eKeys.playPause), findsWidgets);
        } else {
          debugPrint('[E2E] Lesson opened but no player control found — '
              'may be a text lesson; continuing.');
        }
      } else {
        debugPrint('[E2E] Course has no lesson tiles; skipping playback.');
      }
    }

    // ── Logout ───────────────────────────────────────────────────────────
    final loggedOut = await _logoutIfPossible(tester);
    expect(loggedOut, isTrue, reason: 'logout did not return to the login screen');
  }, timeout: const Timeout(Duration(minutes: 5)));
}

/// Goes Profile → Settings sheet → Logout, returning true once the login
/// screen is shown again. Logout lives inside the Settings bottom sheet, so
/// the sheet must be opened first. Safe to call from anywhere in the shell.
Future<bool> _logoutIfPossible(WidgetTester tester) async {
  if (await _pumpUntil(tester, find.byKey(E2eKeys.navProfile),
      timeout: const Duration(seconds: 10))) {
    await tester.tap(find.byKey(E2eKeys.navProfile));
    await tester.pump(const Duration(seconds: 1));

    // Open the Settings sheet that contains Logout.
    if (await _pumpUntil(tester, find.byKey(E2eKeys.settingsRow),
        timeout: const Duration(seconds: 8))) {
      await tester.tap(find.byKey(E2eKeys.settingsRow));
      await tester.pump(const Duration(milliseconds: 600));
    }

    final logout = find.byKey(E2eKeys.logoutButton);
    if (await _pumpUntil(tester, logout, timeout: const Duration(seconds: 8))) {
      await tester.tap(logout);
      await tester.pump(const Duration(seconds: 1));
    }
  }
  return _pumpUntil(tester, find.byKey(E2eKeys.loginEmail),
      timeout: const Duration(seconds: 15));
}

/// Pumps in short increments until [finder] matches at least one widget or
/// [timeout] elapses. Avoids `pumpAndSettle`, which never completes on screens
/// with a continuously-ticking stream (the audio position bar) or a spinner.
Future<bool> _pumpUntil(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 15),
  Duration step = const Duration(milliseconds: 250),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(deadline)) {
    await tester.pump(step);
    if (tester.any(finder)) return true;
  }
  return tester.any(finder);
}
