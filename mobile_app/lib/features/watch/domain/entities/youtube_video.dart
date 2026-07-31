/// A free video hosted on YouTube.
///
/// Deliberately not part of the `videos` pipeline: nothing streams
/// through R2 or Bunny, there is no licensing, and no premium gate. The
/// app shows a thumbnail and hands off to YouTube.
class YoutubeVideo {
  final String id;
  final String title;
  final String? description;
  final String youtubeUrl;
  final String youtubeId;
  final String? thumbnailUrl;

  const YoutubeVideo({
    required this.id,
    required this.title,
    required this.youtubeUrl,
    required this.youtubeId,
    this.description,
    this.thumbnailUrl,
  });

  /// Falls back to YouTube's predictable thumbnail path, so a row saved
  /// without one still renders an image rather than a grey box.
  String get thumbnail =>
      (thumbnailUrl != null && thumbnailUrl!.isNotEmpty)
          ? thumbnailUrl!
          : 'https://i.ytimg.com/vi/$youtubeId/hqdefault.jpg';

  factory YoutubeVideo.fromMap(Map<String, dynamic> map) => YoutubeVideo(
        id: map['id'] as String? ?? '',
        title: map['title'] as String? ?? 'Untitled',
        description: map['description'] as String?,
        youtubeUrl: map['youtube_url'] as String? ?? '',
        youtubeId: map['youtube_id'] as String? ?? '',
        thumbnailUrl: map['thumbnail_url'] as String?,
      );
}
