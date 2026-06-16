import 'package:supabase_flutter/supabase_flutter.dart';

class HomeRemoteDataSource {
  final SupabaseClient _client;

  HomeRemoteDataSource(this._client);

  Future<List<Map<String, dynamic>>> getFeaturedVideos({int limit = 12}) {
    return _client
        .from('videos')
        .select('id, title, thumbnail_url, duration_seconds, is_premium')
        .eq('status', 'published')
        .order('view_count', ascending: false)
        .limit(limit);
  }

  Future<List<Map<String, dynamic>>> getFeaturedAudios({int limit = 12}) {
    return _client
        .from('audios')
        .select('id, title, cover_art_url, artist, duration_seconds, is_premium')
        .eq('status', 'published')
        .order('play_count', ascending: false)
        .limit(limit);
  }

  Future<List<Map<String, dynamic>>> getRecentlyAdded({int limit = 12}) {
    return _client
        .from('videos')
        .select('id, title, thumbnail_url, duration_seconds, is_premium')
        .eq('status', 'published')
        .order('created_at', ascending: false)
        .limit(limit);
  }

  Future<List<Map<String, dynamic>>> getCategories({int limit = 16}) {
    return _client
        .from('categories')
        .select('id, name, slug')
        .order('sort_order', ascending: true)
        .limit(limit);
  }

  /// Joins watch_history with videos/audios. Two separate queries (rather
  /// than a single cross-table join, which PostgREST can't express cleanly
  /// for an either-or foreign key) merged client-side by recency.
  Future<List<Map<String, dynamic>>> getContinueWatching({
    required String userId,
    int limit = 12,
  }) async {
    final videoRows = await _client
        .from('watch_history')
        .select(
          'id, progress_seconds, duration_seconds, last_watched_at, '
          'video_id, videos(id, title, thumbnail_url)',
        )
        .eq('user_id', userId)
        .eq('completed', false)
        .not('video_id', 'is', null)
        .order('last_watched_at', ascending: false)
        .limit(limit);

    final audioRows = await _client
        .from('watch_history')
        .select(
          'id, progress_seconds, duration_seconds, last_watched_at, '
          'audio_id, audios(id, title, cover_art_url)',
        )
        .eq('user_id', userId)
        .eq('completed', false)
        .not('audio_id', 'is', null)
        .order('last_watched_at', ascending: false)
        .limit(limit);

    final merged = [...videoRows, ...audioRows]
      ..sort((a, b) => DateTime.parse(b['last_watched_at'] as String)
          .compareTo(DateTime.parse(a['last_watched_at'] as String)));

    return merged.take(limit).toList();
  }
}
