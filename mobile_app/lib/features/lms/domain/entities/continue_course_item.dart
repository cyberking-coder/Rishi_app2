import 'lesson.dart';

/// The lesson this user opened most recently, with enough of its course
/// attached to draw a card without a second query.
///
/// Named for what it is used for rather than what it is read from. The
/// row behind it is a `lesson_progress` record; what the home screen
/// wants is "where was I", and that question is only answerable with the
/// course's title and artwork alongside the lesson's own.
class ContinueCourseItem {
  /// The full lesson, built the same way the curriculum builds it, so
  /// it can be handed straight to [launchLesson]. Carrying a real Lesson
  /// rather than an id is what lets the resume card open the lesson
  /// itself — the player needs the media fields, and an id alone would
  /// mean a second round trip or a fabricated object.
  final Lesson lesson;

  final String courseId;
  final String courseTitle;
  final String? courseCoverImageUrl;

  /// How far in, in seconds. Zero for a lesson that was opened but whose
  /// position was never reported — which is most of them, since only the
  /// audio pipeline tracks a position.
  final int progressSeconds;

  /// Whether this lesson has been finished. A finished lesson is still
  /// worth showing: "you just completed this" is as useful a place to
  /// come back to as "you were halfway through", and hiding it would
  /// leave the row empty for anyone who works through a course cleanly.
  final bool completed;

  final DateTime lastAccessedAt;

  const ContinueCourseItem({
    required this.lesson,
    required this.courseId,
    required this.courseTitle,
    required this.courseCoverImageUrl,
    required this.progressSeconds,
    required this.completed,
    required this.lastAccessedAt,
  });

  String get lessonId => lesson.id;
  String get lessonTitle => lesson.title;

  /// Builds from the nested PostgREST shape produced by
  /// [LmsRemoteDataSource.getLastAccessedLesson], or null when any of the
  /// joins came back empty.
  ///
  /// Null rather than throwing, and null rather than a half-populated
  /// object. A lesson whose course was archived, or whose module was
  /// deleted, arrives here with holes in it — and the honest response to
  /// "we cannot say where you were" is to show nothing, not to draw a
  /// card pointing at a course that no longer exists.
  static ContinueCourseItem? fromRow(Map<String, dynamic> row) {
    final lesson = row['lessons'];
    if (lesson is! Map) return null;

    final module = lesson['course_modules'];
    if (module is! Map) return null;

    final course = module['courses'];
    if (course is! Map) return null;

    final courseId = course['id'] as String?;
    if (courseId == null) return null;

    final completed = row['completed'] as bool? ?? false;
    final accessed = row['last_accessed_at'] as String?;

    return ContinueCourseItem(
      lesson: Lesson.fromMap(
        Map<String, dynamic>.from(lesson),
        completed: completed,
      ),
      courseId: courseId,
      courseTitle: course['title'] as String? ?? 'Course',
      courseCoverImageUrl: course['cover_image_url'] as String?,
      progressSeconds: (row['progress_seconds'] as num?)?.toInt() ?? 0,
      completed: completed,
      lastAccessedAt:
          accessed == null ? DateTime.now() : DateTime.parse(accessed).toLocal(),
    );
  }
}
