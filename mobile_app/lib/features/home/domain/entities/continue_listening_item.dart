class ContinueListeningItem {
  final String listenHistoryId;
  final String audioId;
  final String title;
  final String? teacher;
  final String? coverArtUrl;
  final int progressSeconds;
  final int durationSeconds;

  const ContinueListeningItem({
    required this.listenHistoryId,
    required this.audioId,
    required this.title,
    required this.progressSeconds,
    required this.durationSeconds,
    this.teacher,
    this.coverArtUrl,
  });

  double get progressFraction =>
      durationSeconds == 0 ? 0 : (progressSeconds / durationSeconds).clamp(0, 1);
}
