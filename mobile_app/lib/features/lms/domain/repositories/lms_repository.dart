import '../entities/course_summary.dart';
import '../entities/lesson.dart';

abstract class LmsRepository {
  Future<List<CourseSummary>> getCourses();
  Future<CourseDetail> getCourseDetail(String courseId);
  Future<void> markLessonCompleted(String lessonId);
}
