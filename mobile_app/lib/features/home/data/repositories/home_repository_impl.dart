import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/entities/audio_summary.dart';
import '../../domain/entities/category_summary.dart';
import '../../domain/entities/continue_watching_item.dart';
import '../../domain/entities/video_summary.dart';
import '../../domain/repositories/home_repository.dart';
import '../datasources/home_remote_datasource.dart';

class HomeRepositoryImpl implements HomeRepository {
  final HomeRemoteDataSource _remote;
  final SupabaseClient _client;

  HomeRepositoryImpl(this._remote, this._client);

  @override
  Future<List<VideoSummary>> getFeaturedVideos() async {
    final rows = await _remote.getFeaturedVideos();
    return rows.map(VideoSummary.fromMap).toList();
  }

  @override
  Future<List<AudioSummary>> getFeaturedAudios() async {
    final rows = await _remote.getFeaturedAudios();
    return rows.map(AudioSummary.fromMap).toList();
  }

  @override
  Future<List<VideoSummary>> getRecentlyAdded() async {
    final rows = await _remote.getRecentlyAdded();
    return rows.map(VideoSummary.fromMap).toList();
  }

  @override
  Future<List<CategorySummary>> getCategories() async {
    final rows = await _remote.getCategories();
    return rows.map(CategorySummary.fromMap).toList();
  }

  @override
  Future<List<ContinueWatchingItem>> getContinueWatching() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return const [];

    final rows = await _remote.getContinueWatching(userId: userId);

    return rows.map((row) {
      final isVideo = row['video_id'] != null;
      final content = (isVideo ? row['videos'] : row['audios'])
          as Map<String, dynamic>?;

      return ContinueWatchingItem(
        watchHistoryId: row['id'] as String,
        contentId: (isVideo ? row['video_id'] : row['audio_id']) as String,
        type: isVideo ? ContinueWatchingType.video : ContinueWatchingType.audio,
        title: content?['title'] as String? ?? 'Untitled',
        thumbnailUrl: isVideo
            ? content?['thumbnail_url'] as String?
            : content?['cover_art_url'] as String?,
        progressSeconds: row['progress_seconds'] as int? ?? 0,
        durationSeconds: row['duration_seconds'] as int? ?? 0,
      );
    }).toList();
  }
}
