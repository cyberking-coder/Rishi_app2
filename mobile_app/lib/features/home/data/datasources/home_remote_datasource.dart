import 'package:supabase_flutter/supabase_flutter.dart';

class HomeRemoteDataSource {
  final SupabaseClient _client;

  HomeRemoteDataSource(this._client);

  /// The columns every audio-browse list selects, plus the ids of any
  /// lessons that point at the row. An audio that is a course lesson
  /// (lessons.audio_id → audios.id) must not appear in the standalone
  /// audio section — it is taught inside its course, not browsed loose —
  /// so [_withoutCourseAudios] drops those rows and strips the embedded
  /// `lessons` key before the result reaches the repository mapping.
  static const _audioColumns =
      'id, title, cover_art_url, artist, duration_seconds, is_premium, '
      'lessons(id)';

  /// Removes audios referenced by a course lesson, then strips the helper
  /// `lessons` embed so the shape matches what callers already expect.
  List<Map<String, dynamic>> _withoutCourseAudios(
    List<Map<String, dynamic>> rows, {
    int? limit,
  }) {
    final out = <Map<String, dynamic>>[];
    for (final row in rows) {
      final lessons = row['lessons'];
      final isCourseAudio = lessons is List && lessons.isNotEmpty;
      if (isCourseAudio) continue;
      row.remove('lessons');
      out.add(row);
      if (limit != null && out.length >= limit) break;
    }
    return out;
  }

  // Course audios are filtered out client-side, so the top-N lists
  // over-fetch by this margin to stay full after a few are dropped.
  static const _courseAudioBuffer = 12;

  Future<List<Map<String, dynamic>>> getFeaturedAudios({int limit = 12}) async {
    final rows = await _client
        .from('audios')
        .select(_audioColumns)
        .eq('status', 'published')
        .order('play_count', ascending: false)
        .limit(limit + _courseAudioBuffer);
    return _withoutCourseAudios(
      List<Map<String, dynamic>>.from(rows),
      limit: limit,
    );
  }

  Future<List<Map<String, dynamic>>> getRecentlyAdded({int limit = 12}) async {
    final rows = await _client
        .from('audios')
        .select(_audioColumns)
        .eq('status', 'published')
        .order('created_at', ascending: false)
        .limit(limit + _courseAudioBuffer);
    return _withoutCourseAudios(
      List<Map<String, dynamic>>.from(rows),
      limit: limit,
    );
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
      {int limit = 30}) async {
    final rows = await _client
        .from('audios')
        .select(_audioColumns)
        .eq('status', 'published')
        .or('title.ilike.%$query%,artist.ilike.%$query%')
        .limit(limit + _courseAudioBuffer);
    return _withoutCourseAudios(
      List<Map<String, dynamic>>.from(rows),
      limit: limit,
    );
  }

  Future<List<Map<String, dynamic>>> getAudiosByCategory(String categoryId,
      {int limit = 50}) async {
    final rows = await _client
        .from('audio_categories')
        .select(
            'audios(id, title, cover_art_url, artist, duration_seconds, is_premium, lessons(id))')
        .eq('category_id', categoryId)
        .limit(limit);
    // Rows here are {audios: {...}}; drop the ones whose audio is a course
    // lesson, then strip the helper `lessons` embed from the kept ones.
    final out = <Map<String, dynamic>>[];
    for (final row in List<Map<String, dynamic>>.from(rows)) {
      final audio = row['audios'];
      if (audio is! Map) continue;
      final lessons = audio['lessons'];
      if (lessons is List && lessons.isNotEmpty) continue;
      audio.remove('lessons');
      out.add(row);
    }
    return out;
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
