import '../../domain/entities/audio_playback_source.dart';

class AudioPlaybackSourceModel {
  static AudioPlaybackSource fromJson(Map<String, dynamic> json) {
    return AudioPlaybackSource(
      audioId: json['audio_id'] as String,
      url: json['url'] as String,
      resumePositionSeconds: json['resume_position_seconds'] as int? ?? 0,
      expiresInSeconds: json['expires_in_seconds'] as int? ?? 600,
      issuedAt: DateTime.now(),
    );
  }
}
