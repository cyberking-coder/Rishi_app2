import 'package:supabase_flutter/supabase_flutter.dart';

class HomeRemoteDataSource {
  final SupabaseClient _client;

  HomeRemoteDataSource(this._client);

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
        .from('audios')
        .select('id, title, cover_art_url, artist, duration_seconds, is_premium')
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

  /// Full-text-ish search over published audio titles/artists.
  Future<List<Map<String, dynamic>>> searchAudios(String query,
      {int limit = 40}) {
    final q = query.trim();
    return _client
        .from('audios')
        .select('id, title, cover_art_url, artist, duration_seconds, is_premium')
        .eq('status', 'published')
        .or('title.ilike.%$q%,artist.ilike.%$q%')
        .order('play_count', ascending: false)
        .limit(limit);
  }

  /// All published audios in a given category (via the join table).
  Future<List<Map<String, dynamic>>> getAudiosByCategory(String categoryId,
      {int limit = 60}) async {
    final rows = await _client
        .from('audio_categories')
        .select(
            'audios!inner(id, title, cover_art_url, artist, duration_seconds, is_premium, status)')
        .eq('category_id', categoryId)
        .limit(limit);
    return rows
        .map((r) => r['audios'] as Map<String, dynamic>)
        .where((a) => a['status'] == 'published')
        .toList();
  }

  Future<List<Map<String, dynamic>>> getContinueListening({
    required String userId,
    int limit = 12,
  }) {
    return _client
        .from('watch_history')
        .select(
          'id, progress_seconds, duration_seconds, last_watched_at, '
          'audio_id, audios(id, title, cover_art_url, artist)',
        )
        .eq('user_id', userId)
        .eq('completed', false)
        .not('audio_id', 'is', null)
        .order('last_watched_at', ascending: false)
        .limit(limit);
  }
}
