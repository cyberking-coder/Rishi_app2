/// Reusable test data builders.
///
/// Phase 1 seeds this with the shapes real code already consumes, so later
/// phases build on them instead of re-deriving the same maps. Each builder
/// returns the PostgREST-style `Map<String, dynamic>` the data sources parse,
/// with sensible defaults overridable per field.
library;

/// An `audios` row as selected by the home/audio browse queries.
Map<String, dynamic> audioRow({
  String id = 'audio-1',
  String title = 'Morning Stillness',
  String? artist = 'Anurag Rishi',
  String? coverArtUrl = 'https://example.com/cover.jpg',
  int? durationSeconds = 600,
  bool isPremium = false,
  List<Map<String, dynamic>>? lessons,
}) =>
    <String, dynamic>{
      'id': id,
      'title': title,
      'artist': artist,
      'cover_art_url': coverArtUrl,
      'duration_seconds': durationSeconds,
      'is_premium': isPremium,
      if (lessons != null) 'lessons': lessons,
    };

/// A `lessons` embed marking an audio as belonging to a course.
List<Map<String, dynamic>> lessonLink({String id = 'lesson-1'}) => [
      {'id': id},
    ];
