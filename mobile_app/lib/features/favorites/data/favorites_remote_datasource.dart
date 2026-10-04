import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/auth_failure.dart';

/// Reads and writes the current user's audio favourites (RLS scopes every
/// query to them). Favourites are audio-only by design.
class FavoritesRemoteDataSource {
  final SupabaseClient _client;

  FavoritesRemoteDataSource(this._client);

  String get _uid {
    final id = _client.auth.currentUser?.id;
    if (id == null) throw AuthFailure.unknown('Not logged in');
    return id;
  }

  /// The set of audio ids the user has favourited — cheap, for heart state.
  Future<Set<String>> favoriteIds() async {
    final rows = await _client
        .from('favorites')
        .select('audio_id')
        .eq('user_id', _uid);
    return {
      for (final r in rows as List) r['audio_id'] as String,
    };
  }

  /// The favourited audios as full rows (newest first), joined through to the
  /// `audios` table — only published audios come back (RLS on audios).
  Future<List<Map<String, dynamic>>> favoriteAudios() async {
    final rows = await _client
        .from('favorites')
        .select(
          'created_at, audios(id, title, cover_art_url, artist, '
          'duration_seconds, is_premium)',
        )
        .eq('user_id', _uid)
        .order('created_at', ascending: false);
    return [
      for (final r in rows as List)
        if (r['audios'] is Map) Map<String, dynamic>.from(r['audios'] as Map),
    ];
  }

  Future<void> add(String audioId) async {
    // Idempotent: a repeat tap must not error on the unique constraint.
    await _client.from('favorites').upsert(
      {'user_id': _uid, 'audio_id': audioId},
      onConflict: 'user_id,audio_id',
    );
  }

  Future<void> remove(String audioId) async {
    await _client
        .from('favorites')
        .delete()
        .eq('user_id', _uid)
        .eq('audio_id', audioId);
  }
}
