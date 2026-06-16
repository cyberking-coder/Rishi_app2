class AudioPlaybackSource {
  final String audioId;
  final String url;
  final int resumePositionSeconds;
  final int expiresInSeconds;
  final DateTime issuedAt;

  const AudioPlaybackSource({
    required this.audioId,
    required this.url,
    required this.resumePositionSeconds,
    required this.expiresInSeconds,
    required this.issuedAt,
  });
}
