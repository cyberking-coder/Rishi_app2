import '../../domain/entities/playback_source.dart';
import '../../domain/repositories/player_repository.dart';
import '../datasources/player_remote_datasource.dart';
import '../models/playback_source_model.dart';

class PlayerRepositoryImpl implements PlayerRepository {
  final PlayerRemoteDataSource _remote;

  PlayerRepositoryImpl(this._remote);

  @override
  Future<PlaybackSource> getPlaybackSource(String videoId) async {
    final json = await _remote.issuePlaybackLicense(videoId);
    return PlaybackSourceModel.fromJson(json);
  }

  @override
  Future<void> updateWatchProgress({
    required String videoId,
    required int progressSeconds,
    required int durationSeconds,
    required bool completed,
  }) {
    return _remote.upsertWatchProgress(
      videoId: videoId,
      progressSeconds: progressSeconds,
      durationSeconds: durationSeconds,
      completed: completed,
    );
  }
}
