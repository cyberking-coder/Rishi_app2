import 'package:flutter_test/flutter_test.dart';
import 'package:meditation_app/features/audio/data/models/audio_playback_source_model.dart';

/// Parsing tests for the audio license response. The happy path and the
/// default fallbacks (resume position, expiry) are what the player relies on
/// when it builds a stream.
void main() {
  test('parses a full license response', () {
    final src = AudioPlaybackSourceModel.fromJson({
      'audio_id': 'a1',
      'url': 'https://r2.example/x.m4a?sig=abc',
      'resume_position_seconds': 42,
      'expires_in_seconds': 21600,
    });
    expect(src.audioId, 'a1');
    expect(src.url, 'https://r2.example/x.m4a?sig=abc');
    expect(src.resumePositionSeconds, 42);
    expect(src.expiresInSeconds, 21600);
    expect(src.issuedAt, isNotNull);
  });

  test('applies defaults when optional fields are absent', () {
    final src = AudioPlaybackSourceModel.fromJson({
      'audio_id': 'a1',
      'url': 'https://r2.example/x.m4a',
    });
    expect(src.resumePositionSeconds, 0);
    expect(src.expiresInSeconds, 600);
  });
}
