class CourseSummary {
  final String id;
  final String title;
  final String? description;
  final String? coverImageUrl;
  final bool isPremium;
  final int lessonCount;
  final int completedLessonCount;

  /// Minor units (paise). 0 means free.
  final int priceAmount;

  /// True when this user has already bought (or been granted) the course.
  final bool owned;

  const CourseSummary({
    required this.id,
    required this.title,
    required this.isPremium,
    this.description,
    this.coverImageUrl,
    this.lessonCount = 0,
    this.completedLessonCount = 0,
    this.priceAmount = 0,
    this.owned = false,
  });

  bool get isFree => priceAmount == 0;

  /// Whether the catalog should show a lock. A free course is open to
  /// everyone, and an owned one is unlocked regardless of price.
  bool get isLocked => !isFree && !owned;

  /// Rupees, without trailing decimals when it's a whole number — which
  /// it almost always is for course pricing.
  String get priceLabel {
    if (isFree) return 'Free';
    final rupees = priceAmount / 100;
    return rupees == rupees.roundToDouble()
        ? '₹${rupees.round()}'
        : '₹${rupees.toStringAsFixed(2)}';
  }

  double get progressFraction =>
      lessonCount == 0 ? 0 : completedLessonCount / lessonCount;

  bool get isStarted => completedLessonCount > 0;

  factory CourseSummary.fromMap(
    Map<String, dynamic> map, {
    int lessonCount = 0,
    int completedLessonCount = 0,
    bool owned = false,
  }) =>
      CourseSummary(
        id: map['id'] as String? ?? '',
        title: map['title'] as String? ?? 'Untitled',
        description: map['description'] as String?,
        coverImageUrl: map['cover_image_url'] as String?,
        // Fail closed, matching AudioSummary: an unknown flag is treated
        // as premium rather than accidentally exposing paid content.
        isPremium: map['is_premium'] as bool? ?? true,
        lessonCount: lessonCount,
        completedLessonCount: completedLessonCount,
        priceAmount: (map['price_amount'] as num?)?.toInt() ?? 0,
        owned: owned,
      );
}
