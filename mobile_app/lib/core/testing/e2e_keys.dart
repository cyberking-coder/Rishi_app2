import 'package:flutter/widgets.dart';

/// Stable widget keys used by the device-level UI-journey integration test
/// (`integration_test/e2e_user_journey_test.dart`). Centralised so the app
/// and the test never drift on a magic string.
///
/// These add no behaviour — they only make specific widgets findable from a
/// test. Fixed keys are for one-of-a-kind controls; the `*CardPrefix`
/// helpers build a per-id key for list items (siblings in a list must have
/// unique keys), and the test matches on the prefix to tap the first one.
class E2eKeys {
  E2eKeys._();

  // Login screen.
  static const loginEmail = Key('e2e_login_email');
  static const loginPassword = Key('e2e_login_password');
  static const loginSubmit = Key('e2e_login_submit');

  // Bottom-nav / shell tabs.
  static const navHome = Key('e2e_nav_home');
  static const navCourses = Key('e2e_nav_courses');
  static const navProfile = Key('e2e_nav_profile');

  // Profile.
  static const settingsRow = Key('e2e_settings_row');
  static const logoutButton = Key('e2e_logout');

  // Audio player transport.
  static const playPause = Key('e2e_play_pause');

  // List items (unique per id).
  static const _courseCardPrefix = 'e2e_courseCard_';
  static const _lessonTilePrefix = 'e2e_lessonTile_';

  static Key courseCard(String id) => Key('$_courseCardPrefix$id');
  static Key lessonTile(String id) => Key('$_lessonTilePrefix$id');

  static bool isCourseCard(Key? k) => _hasPrefix(k, _courseCardPrefix);
  static bool isLessonTile(Key? k) => _hasPrefix(k, _lessonTilePrefix);

  static bool _hasPrefix(Key? k, String prefix) =>
      k is ValueKey<String> && k.value.startsWith(prefix);
}
