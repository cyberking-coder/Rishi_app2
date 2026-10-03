// Shared helpers for the device-level UI-journey tests.
//
// `pumpUntil` is used everywhere instead of `pumpAndSettle`, which never
// completes on screens with a continuously-ticking stream (the audio
// position bar) or a spinner.

import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:meditation_app/core/testing/e2e_keys.dart';
import 'package:meditation_app/main.dart' as app;

const e2eEmail = String.fromEnvironment('E2E_EMAIL');
const e2ePassword = String.fromEnvironment('E2E_PASSWORD');

bool get e2eHasCreds => e2eEmail.isNotEmpty && e2ePassword.isNotEmpty;

/// Pumps in short increments until [finder] matches or [timeout] elapses.
Future<bool> pumpUntil(
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

/// Boots the real app and ensures we are logged in and on the home shell.
/// Returns true on success; false if login never reached the shell.
Future<bool> bootAndLogin(WidgetTester tester) async {
  await app.main();
  await tester.pump(const Duration(seconds: 1));

  // Already signed in from a previous run? Then the shell is (or will be)
  // showing; just wait for a tab to confirm.
  if (Supabase.instance.client.auth.currentSession != null) {
    if (await pumpUntil(tester, find.byKey(E2eKeys.navHome),
        timeout: const Duration(seconds: 15))) {
      return true;
    }
  }

  if (!await pumpUntil(tester, find.byKey(E2eKeys.loginEmail),
      timeout: const Duration(seconds: 20))) {
    // Neither logged in nor a login screen — give up.
    return tester.any(find.byKey(E2eKeys.navHome));
  }

  await tester.enterText(find.byKey(E2eKeys.loginEmail), e2eEmail);
  await tester.enterText(find.byKey(E2eKeys.loginPassword), e2ePassword);
  await tester.pump(const Duration(milliseconds: 300));
  await tester.tap(find.byKey(E2eKeys.loginSubmit));

  return pumpUntil(tester, find.byKey(E2eKeys.navHome),
      timeout: const Duration(seconds: 25));
}

/// First audio card on the Home shelf, if any.
Finder audioCardFinder() =>
    find.byWidgetPredicate((w) => E2eKeys.isAudioCard(w.key));
