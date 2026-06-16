class VideoSummary {
  final String id;
  final String title;
  final String? thumbnailUrl;
  final int? durationSeconds;
  final bool isPremium;

  const VideoSummary({
    required this.id,
    required this.title,
    required this.isPremium,
    this.thumbnailUrl,
    this.durationSeconds,
  });

  factory VideoSummary.fromMap(Map<String, dynamic> map) => VideoSummary(
        id: map['id'] as String,
        title: map['title'] as String,
        thumbnailUrl: map['thumbnail_url'] as String?,
        durationSeconds: map['duration_seconds'] as int?,
        isPremium: map['is_premium'] as bool? ?? true,
      );
}
