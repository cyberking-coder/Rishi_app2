enum ContinueWatchingType { video, audio }

class ContinueWatchingItem {
  final String watchHistoryId;
  final String contentId;
  final ContinueWatchingType type;
  final String title;
  final String? thumbnailUrl;
  final int progressSeconds;
  final int durationSeconds;

  const ContinueWatchingItem({
    required this.watchHistoryId,
    required this.contentId,
    required this.type,
    required this.title,
    required this.progressSeconds,
    required this.durationSeconds,
    this.thumbnailUrl,
  });

  double get progressFraction =>
      durationSeconds == 0 ? 0 : (progressSeconds / durationSeconds).clamp(0, 1);
}
