class AudioTrack {
  final String id;
  final String title;
  final String? artist;
  final String? coverArtUrl;
  final int? durationSeconds;

  const AudioTrack({
    required this.id,
    required this.title,
    this.artist,
    this.coverArtUrl,
    this.durationSeconds,
  });

  factory AudioTrack.fromMap(Map<String, dynamic> map) => AudioTrack(
        id: map['id'] as String,
        title: map['title'] as String,
        artist: map['artist'] as String?,
        coverArtUrl: map['cover_art_url'] as String?,
        durationSeconds: map['duration_seconds'] as int?,
      );
}
