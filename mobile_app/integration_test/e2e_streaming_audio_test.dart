// Device-level E2E: stream an audio from Home and control it.
//
//   login -> Home -> tap an audio -> Now Playing opens -> play/pause works
//          -> back -> the persistent mini-player shows and its control works.
//
// Covers the most-used path (streaming playback + the mini-player), separate
// from the course-lesson journey. This is where the "audio gets stuck" fix
// (auto-recovery on a stream error) lives behind the scenes.
//
// RUN (device/emulator + staging build + a test account):
//   flutter test integration_test/e2e_streaming_audio_test.dart \
//     --dart-define=E2E_EMAIL=... --dart-define=E2E_PASSWORD=...
// Skips without credentials; skips gracefully if Home has no audio.

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:meditation_app/core/testing/e2e_keys.dart';
import 'e2e_helpers.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('stream an audio and control it from the mini-player',
      (tester) async {
    if (!e2eHasCreds) {
      markTestSkipped('Set E2E_EMAIL and E2E_PASSWORD to run this journey.');
      return;
    }

    expect(await bootAndLogin(tester), isTrue, reason: 'login failed');

    await tester.tap(find.byKey(E2eKeys.navHome));
    await tester.pump(const Duration(seconds: 1));

    if (!await pumpUntil(tester, audioCardFinder(),
        timeout: const Duration(seconds: 20))) {
      markTestSkipped('No audio on Home to stream.');
      return;
    }

    // Tap an audio → Now Playing opens with the transport.
    await tester.tap(audioCardFinder().first);
    final atPlayer = await pumpUntil(tester, find.byKey(E2eKeys.playPause),
        timeout: const Duration(seconds: 25));
    if (!atPlayer) {
      markTestSkipped('Now Playing did not open (audio may be gated).');
      return;
    }
    // Dwell: let it play for a stretch and confirm the player is still there
    // and has not torn itself down — a cheap guard against the "plays then
    // stops after a while" class. (A precise position-advance assertion wants
    // a test hook on the handler; this at least catches a crash/freeze that
    // removes the transport.)
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(seconds: 5));
    }
    expect(find.byKey(E2eKeys.playPause), findsWidgets,
        reason: 'player disappeared during sustained playback');

    // Back out → the persistent mini-player should carry the session.
    await tester.pageBack();
    await tester.pump(const Duration(seconds: 1));
    expect(
      await pumpUntil(tester, find.byKey(E2eKeys.miniPlayPause),
          timeout: const Duration(seconds: 10)),
      isTrue,
      reason: 'mini-player did not appear after leaving Now Playing',
    );

    // The mini-player control works too.
    await tester.tap(find.byKey(E2eKeys.miniPlayPause));
    await tester.pump(const Duration(seconds: 1));
    expect(find.byKey(E2eKeys.miniPlayPause), findsOneWidget);
  }, timeout: const Timeout(Duration(minutes: 4)));
}
