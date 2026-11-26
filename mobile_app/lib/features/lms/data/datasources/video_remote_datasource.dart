import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/device/active_device.dart';
import '../../../../core/device/device_info_service.dart';
import '../../../../core/errors/auth_failure.dart';
import '../../domain/entities/playback_sources.dart';

/// Requests a signed playback URL for a video lesson.
///
/// Mirrors AudioRemoteDataSource.issueAudioLicense, including its error
/// mapping, so both media types surface the same typed failures to the UI.
class VideoRemoteDataSource {
  final SupabaseClient _client;
  final DeviceInfoService _deviceInfo;

  VideoRemoteDataSource(this._client, this._deviceInfo);

  Future<PlaybackSources> issuePlaybackUrl(String videoId) async {
    final deviceId = await resolveActiveDeviceId(_client, _deviceInfo);

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

    // `qualities` is the full picture for both backends: Bunny returns
    // Auto followed by each rendition off the master playlist, the R2
    // path returns its own ladder. Playing qualities.first keeps the
    // old behaviour — it is the adaptive stream where there is one.
    final rows = (data['qualities'] as List?) ?? const [];
    final options = [
      for (final row in rows)
        if (row is Map && row['url'] is String)
          PlaybackQuality(
            label: (row['label'] as String?) ?? 'Auto',
            url: row['url'] as String,
          ),
    ];

    if (options.isNotEmpty) return PlaybackSources(options: options);

    // Older deployments of the function answered with hls_url only.
    final hlsUrl = data['hls_url'] as String?;
    if (hlsUrl != null) {
      return PlaybackSources(
        options: [PlaybackQuality(label: 'Auto', url: hlsUrl)],
      );
    }

    throw AuthFailure.unknown('No playable version of this video.');
  }
}
