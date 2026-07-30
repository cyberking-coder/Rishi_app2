import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/errors/auth_failure.dart';

/// Requests a signed playback URL for a video lesson.
///
/// Mirrors AudioRemoteDataSource.issueAudioLicense, including its error
/// mapping, so both media types surface the same typed failures to the UI.
class VideoRemoteDataSource {
  final SupabaseClient _client;

  VideoRemoteDataSource(this._client);

  Future<String> issuePlaybackUrl(String videoId) async {
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
        if (error.toLowerCase().contains('access period')) {
          throw AuthFailure.accessExpired();
        }
        throw AuthFailure.deviceLocked();
      }
      if (response.status == 402) {
        throw AuthFailure.premiumRequired();
      }
      // 409: uploaded but Bunny hasn't finished encoding yet.
      throw AuthFailure.unknown(error);
    }

    final data = response.data as Map<String, dynamic>;

    // Bunny returns a single adaptive HLS stream; the R2 path returns a
    // quality list. Either way the first entry is what we play — with
    // HLS the player picks the rendition itself per segment.
    final hlsUrl = data['hls_url'] as String?;
    if (hlsUrl != null) return hlsUrl;

    final qualities = data['qualities'] as List?;
    if (qualities == null || qualities.isEmpty) {
      throw AuthFailure.unknown('No playable version of this video.');
    }
    return (qualities.first as Map)['url'] as String;
  }

  Future<String> _getActiveDeviceId() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw AuthFailure.unknown('Not logged in');

    final row = await _client
        .from('devices')
        .select('id')
        .eq('user_id', userId)
        .eq('is_active', true)
        .maybeSingle();

    if (row == null) throw AuthFailure.unknown('No active device registered');
    return row['id'] as String;
  }
}
