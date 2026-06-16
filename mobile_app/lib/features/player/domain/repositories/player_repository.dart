import '../entities/playback_source.dart';

abstract class PlayerRepository {
  /// Calls the issue-playback-license Edge Function, which validates
  /// entitlement + device lock server-side and returns signed R2 URLs.
  Future<PlaybackSource> getPlaybackSource(String videoId);

  /// Upserts (user_id, video_id) progress. Called periodically during
  /// playback and once more on pause/exit.
  Future<void> updateWatchProgress({
    required String videoId,
    required int progressSeconds,
    required int durationSeconds,
    required bool completed,
  });
}
