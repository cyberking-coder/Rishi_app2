class AudioSummary {
  final String id;
  final String title;
  final String? coverArtUrl;
  final String? artist;
  final int? durationSeconds;
  final bool isPremium;

  const AudioSummary({
    required this.id,
    required this.title,
    required this.isPremium,
    this.coverArtUrl,
    this.artist,
    this.durationSeconds,
  });

  factory AudioSummary.fromMap(Map<String, dynamic> map) => AudioSummary(
        id: map['id'] as String,
        title: map['title'] as String,
        coverArtUrl: map['cover_art_url'] as String?,
        artist: map['artist'] as String?,
        durationSeconds: map['duration_seconds'] as int?,
        isPremium: map['is_premium'] as bool? ?? true,
      );
}
