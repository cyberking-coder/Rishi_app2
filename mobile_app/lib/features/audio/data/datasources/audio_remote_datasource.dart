import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/errors/auth_failure.dart';

class AudioRemoteDataSource {
  final SupabaseClient _client;

  AudioRemoteDataSource(this._client);

  /// Test-mode: returns a direct public URL if the audio row has one set,
  /// otherwise null (caller then falls back to the signed R2 license flow).
  Future<String?> getDirectUrl(String audioId) async {
    final row = await _client
        .from('audios')
        .select('direct_url')
        .eq('id', audioId)
        .maybeSingle();
    final url = row?['direct_url'] as String?;
    return (url != null && url.isNotEmpty) ? url : null;
  }

  Future<Map<String, dynamic>> issueAudioLicense(String audioId) async {
    final deviceId = await _getActiveDeviceId();

    final response = await _client.functions.invoke(
      'issue-audio-license',
      body: {'audio_id': audioId},
      headers: {'X-Device-Id': deviceId},
    );

    if (response.status != 200) {
      final error = (response.data is Map)
          ? (response.data['error'] as String? ?? 'Playback unavailable')
          : 'Playback unavailable';

      if (response.status == 403) {
        if (error.toLowerCase().contains('access period')) {
          throw AuthFailure.accessExpired();
        }
        throw AuthFailure.deviceLocked();
      }
      throw AuthFailure.unknown(error);
    }

    return response.data as Map<String, dynamic>;
  }

  Future<String> _getActiveDeviceId() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      throw AuthFailure.unknown('Not logged in');
    }

    final row = await _client
        .from('devices')
        .select('id')
        .eq('user_id', userId)
        .eq('is_active', true)
        .maybeSingle();

    if (row == null) {
      throw AuthFailure.unknown('No active device registered');
    }
    return row['id'] as String;
  }

  Future<List<Map<String, dynamic>>> getPlaylistTracks(String playlistId) {
    return _client
        .from('playlist_tracks')
        .select(
          'position, audios(id, title, artist, cover_art_url, duration_seconds)',
        )
        .eq('playlist_id', playlistId)
        .order('position', ascending: true);
  }

  Future<void> upsertListenProgress({
    required String audioId,
    required int progressSeconds,
    required int durationSeconds,
    required bool completed,
  }) async {
    await _client.rpc('upsert_watch_progress', params: {
      'p_video_id': null,
      'p_audio_id': audioId,
      'p_progress_seconds': progressSeconds,
      'p_duration_seconds': durationSeconds,
      'p_completed': completed,
    });
  }
}
