import '../entities/audio_playback_source.dart';
import '../entities/audio_track.dart';

abstract class AudioRepository {
  /// Calls issue-audio-license, validated server-side against entitlement
  /// and the device lock, just like video playback.
  Future<AudioPlaybackSource> getPlaybackSource(String audioId);

  Future<List<AudioTrack>> getPlaylistTracks(String playlistId);

  Future<void> updateListenProgress({
    required String audioId,
    required int progressSeconds,
    required int durationSeconds,
    required bool completed,
  });
}
