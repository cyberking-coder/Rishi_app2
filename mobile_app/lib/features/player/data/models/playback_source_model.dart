import '../../domain/entities/playback_source.dart';
import '../../domain/entities/video_quality.dart';

class PlaybackSourceModel {
  static PlaybackSource fromJson(Map<String, dynamic> json) {
    final qualitiesJson = json['qualities'] as List<dynamic>;

    return PlaybackSource(
      videoId: json['video_id'] as String,
      qualities: qualitiesJson
          .cast<Map<String, dynamic>>()
          .map(
            (q) => VideoQuality(
              label: q['label'] as String,
              url: q['url'] as String,
              bitrate: q['bitrate'] as int?,
            ),
          )
          .toList(),
      resumePositionSeconds: json['resume_position_seconds'] as int? ?? 0,
      issuedAt: DateTime.now(),
      expiresInSeconds: json['expires_in_seconds'] as int? ?? 600,
    );
  }
}
