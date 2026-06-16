import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/errors/auth_failure.dart';

class PlayerRemoteDataSource {
  final SupabaseClient _client;

  PlayerRemoteDataSource(this._client);

  Future<Map<String, dynamic>> issuePlaybackLicense(String videoId) async {
    final deviceId = await _getActiveDeviceId();

    final response = await _client.functions.invoke(
      'issue-playback-license',
      body: {'video_id': videoId},
      headers: {'X-Device-Id': deviceId},
    );

    if (response.status != 200) {
      final error = (response.data is Map)
          ? (response.data['error'] as String? ?? 'Playback unavailable')
          : 'Playback unavailable';

      if (response.status == 403) {
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

  Future<void> upsertWatchProgress({
    required String videoId,
    required int progressSeconds,
    required int durationSeconds,
    required bool completed,
  }) async {
    await _client.rpc('upsert_watch_progress', params: {
      'p_video_id': videoId,
      'p_audio_id': null,
      'p_progress_seconds': progressSeconds,
      'p_duration_seconds': durationSeconds,
      'p_completed': completed,
    });
  }
}
