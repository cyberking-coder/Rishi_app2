import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/entities/youtube_video.dart';

/// RLS already limits this to published rows, so no status filter here.
class YoutubeRemoteDataSource {
  final SupabaseClient _client;

  YoutubeRemoteDataSource(this._client);

  Future<List<YoutubeVideo>> getVideos() async {
    final rows = await _client
        .from('youtube_videos')
        .select('id, title, description, youtube_url, youtube_id, thumbnail_url')
        .order('sort_order', ascending: true)
        .order('created_at', ascending: false);

    return [
      for (final row in rows as List)
        YoutubeVideo.fromMap(Map<String, dynamic>.from(row as Map)),
    ];
  }
}
