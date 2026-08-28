import '../entities/continue_course_item.dart';
import '../entities/course_summary.dart';
import '../entities/lesson.dart';

abstract class LmsRepository {
  Future<List<CourseSummary>> getCourses();
  Future<CourseDetail> getCourseDetail(String courseId);
  Future<void> markLessonCompleted(String lessonId);

  /// Records that the user has just opened [lessonId]. Best-effort.
  Future<void> recordLessonAccess(String lessonId);

  /// Where the user last was in a course, or null if nowhere.
  Future<ContinueCourseItem?> getContinueCourse();
}
