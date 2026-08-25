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
    // audio_categories(count) is a PostgREST embedded aggregate: it comes
    // back as [{"count": n}] per row, one round trip rather than one
    // query per category. If the relationship can't be resolved the
    // column is simply absent, and CategorySummary reads that as zero —
    // the Browse card then shows its name with no count line rather
    // than failing the whole home screen over a subtitle.
    return _client
        .from('categories')
        .select('id, name, slug, audio_categories(count)')
        .order('sort_order', ascending: true)
        .limit(limit);
  }

  Future<List<Map<String, dynamic>>> searchAudios(String query,
      {int limit = 30}) {
    return _client
        .from('audios')
        .select('id, title, cover_art_url, artist, duration_seconds, is_premium')
        .eq('status', 'published')
        .or('title.ilike.%$query%,artist.ilike.%$query%')
        .limit(limit);
  }

  Future<List<Map<String, dynamic>>> getAudiosByCategory(String categoryId,
      {int limit = 50}) {
    return _client
        .from('audio_categories')
        .select('audios(id, title, cover_art_url, artist, duration_seconds, is_premium)')
        .eq('category_id', categoryId)
        .limit(limit);
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
