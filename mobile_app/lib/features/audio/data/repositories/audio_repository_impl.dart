import '../../domain/entities/audio_playback_source.dart';
import '../../domain/entities/audio_track.dart';
import '../../domain/repositories/audio_repository.dart';
import '../datasources/audio_remote_datasource.dart';
import '../models/audio_playback_source_model.dart';

class AudioRepositoryImpl implements AudioRepository {
  final AudioRemoteDataSource _remote;

  AudioRepositoryImpl(this._remote);

  @override
  Future<AudioPlaybackSource> getPlaybackSource(String audioId) async {
    // Test-mode fast path: if the audio has a direct public URL, play it
    // directly without the R2 signing / Edge Function pipeline.
    final directUrl = await _remote.getDirectUrl(audioId);
    if (directUrl != null) {
      return AudioPlaybackSource(
        audioId: audioId,
        url: directUrl,
        resumePositionSeconds: 0,
        expiresInSeconds: 3600,
        issuedAt: DateTime.now(),
      );
    }

    final json = await _remote.issueAudioLicense(audioId);
    return AudioPlaybackSourceModel.fromJson(json);
  }

  @override
  Future<AudioTrack?> getTrack(String audioId) async {
    final row = await _remote.getAudio(audioId);
    return row == null ? null : AudioTrack.fromMap(row);
  }

  @override
  Future<List<AudioTrack>> getPlaylistTracks(String playlistId) async {
    final rows = await _remote.getPlaylistTracks(playlistId);
    return rows
        .map((row) => row['audios'])
        .whereType<Map<String, dynamic>>()
        .map(AudioTrack.fromMap)
        .toList();
  }

  @override
  Future<void> updateListenProgress({
    required String audioId,
    required int progressSeconds,
    required int durationSeconds,
    required bool completed,
  }) {
    return _remote.upsertListenProgress(
      audioId: audioId,
      progressSeconds: progressSeconds,
      durationSeconds: durationSeconds,
      completed: completed,
    );
  }
}
