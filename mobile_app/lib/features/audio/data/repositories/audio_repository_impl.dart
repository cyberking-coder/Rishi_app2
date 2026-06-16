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
    final json = await _remote.issueAudioLicense(audioId);
    return AudioPlaybackSourceModel.fromJson(json);
  }

  @override
  Future<List<AudioTrack>> getPlaylistTracks(String playlistId) async {
    final rows = await _remote.getPlaylistTracks(playlistId);
    return rows
        .map((row) => row['audios'] as Map<String, dynamic>)
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
