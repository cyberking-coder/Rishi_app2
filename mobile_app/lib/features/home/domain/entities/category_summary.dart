class CategorySummary {
  final String id;
  final String name;
  final String slug;

  /// How many audios are filed under this category. Zero also means
  /// "not counted" — the Browse card hides the line either way, which is
  /// the same thing to a reader.
  final int audioCount;

  const CategorySummary({
    required this.id,
    required this.name,
    required this.slug,
    this.audioCount = 0,
  });

  factory CategorySummary.fromMap(Map<String, dynamic> map) => CategorySummary(
        id: map['id'] as String? ?? '',
        name: map['name'] as String? ?? 'Untitled',
        slug: map['slug'] as String? ?? '',
        audioCount: _count(map['audio_categories']),
      );

  /// PostgREST returns an embedded aggregate as a one-element list of
  /// maps. Written defensively because the shape depends on the
  /// relationship resolving, and a home screen should not go red over a
  /// subtitle it could simply omit.
  static int _count(Object? raw) {
    if (raw is List && raw.isNotEmpty) {
      final first = raw.first;
      if (first is Map && first['count'] is int) return first['count'] as int;
    }
    return 0;
  }
}
