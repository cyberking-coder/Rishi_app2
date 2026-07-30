class CourseSummary {
  final String id;
  final String title;
  final String? description;
  final String? coverImageUrl;
  final bool isPremium;
  final int lessonCount;
  final int completedLessonCount;

  const CourseSummary({
    required this.id,
    required this.title,
    required this.isPremium,
    this.description,
    this.coverImageUrl,
    this.lessonCount = 0,
    this.completedLessonCount = 0,
  });

  double get progressFraction =>
      lessonCount == 0 ? 0 : completedLessonCount / lessonCount;

  bool get isStarted => completedLessonCount > 0;

  factory CourseSummary.fromMap(
    Map<String, dynamic> map, {
    int lessonCount = 0,
    int completedLessonCount = 0,
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
      );
}
