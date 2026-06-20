import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/entities/audio_summary.dart';
import '../../domain/entities/category_summary.dart';
import '../../domain/entities/continue_listening_item.dart';
import '../../domain/repositories/home_repository.dart';
import '../datasources/home_remote_datasource.dart';

class HomeRepositoryImpl implements HomeRepository {
  final HomeRemoteDataSource _remote;
  final SupabaseClient _client;

  HomeRepositoryImpl(this._remote, this._client);

  @override
  Future<List<AudioSummary>> getFeaturedAudios() async {
    final rows = await _remote.getFeaturedAudios();
    return rows.map(AudioSummary.fromMap).toList();
  }

  @override
  Future<List<AudioSummary>> getRecentlyAdded() async {
    final rows = await _remote.getRecentlyAdded();
    return rows.map(AudioSummary.fromMap).toList();
  }

  @override
  Future<List<CategorySummary>> getCategories() async {
    final rows = await _remote.getCategories();
    return rows.map(CategorySummary.fromMap).toList();
  }

  @override
  Future<List<ContinueListeningItem>> getContinueListening() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return const [];

    final rows = await _remote.getContinueListening(userId: userId);

    return rows.map((row) {
      final audio = row['audios'] as Map<String, dynamic>?;
      return ContinueListeningItem(
        listenHistoryId: row['id'] as String,
        audioId: row['audio_id'] as String,
        title: audio?['title'] as String? ?? 'Untitled',
        teacher: audio?['artist'] as String?,
        coverArtUrl: audio?['cover_art_url'] as String?,
        progressSeconds: row['progress_seconds'] as int? ?? 0,
        durationSeconds: row['duration_seconds'] as int? ?? 0,
      );
    }).toList();
  }
}
