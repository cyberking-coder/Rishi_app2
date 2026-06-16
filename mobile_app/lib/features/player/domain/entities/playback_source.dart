import 'video_quality.dart';

class PlaybackSource {
  final String videoId;
  final List<VideoQuality> qualities;
  final int resumePositionSeconds;
  final DateTime issuedAt;
  final int expiresInSeconds;

  const PlaybackSource({
    required this.videoId,
    required this.qualities,
    required this.resumePositionSeconds,
    required this.issuedAt,
    required this.expiresInSeconds,
  });

  bool get isExpired =>
      DateTime.now().difference(issuedAt).inSeconds >= expiresInSeconds;

  VideoQuality get defaultQuality => qualities.first;
}
