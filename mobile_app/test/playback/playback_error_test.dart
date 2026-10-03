import 'package:flutter_test/flutter_test.dart';
import 'package:meditation_app/core/errors/auth_failure.dart';
import 'package:meditation_app/features/audio/presentation/utils/playback_error.dart';

/// The play path throws typed AuthFailures; the UI must translate each into
/// an honest, specific message (the device-reset case especially, which used
/// to be mis-shown as a connection error and cost diagnosis time).
void main() {
  test('device lock', () {
    expect(playbackErrorMessage(AuthFailure.deviceLocked()),
        contains('active on another device'));
  });

  test('access expired', () {
    expect(playbackErrorMessage(AuthFailure.accessExpired()),
        contains('access has ended'));
  });

  test('premium required', () {
    expect(playbackErrorMessage(AuthFailure.premiumRequired()),
        contains('premium content'));
  });

  test('network', () {
    expect(playbackErrorMessage(AuthFailure.network()),
        contains('connection'));
  });

  test('unknown with "device" in message maps to re-register hint', () {
    final msg = playbackErrorMessage(
        AuthFailure.unknown('No active device registered'));
    expect(msg, contains('re-registered'));
  });

  test('generic unknown gives a safe fallback', () {
    expect(playbackErrorMessage(AuthFailure.unknown('weird')),
        "Couldn't play this track. Please try again.");
  });

  test('a non-AuthFailure error never crashes, returns generic message', () {
    expect(playbackErrorMessage(Exception('boom')), contains('Check your connection'));
    expect(playbackErrorMessage('a plain string'), contains('Check your connection'));
  });
}
