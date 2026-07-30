import '../../domain/entities/course_summary.dart';
import '../../domain/entities/lesson.dart';
import '../../domain/repositories/lms_repository.dart';
import '../datasources/lms_remote_datasource.dart';

class LmsRepositoryImpl implements LmsRepository {
  final LmsRemoteDataSource _remote;

  LmsRepositoryImpl(this._remote);

  @override
  Future<List<CourseSummary>> getCourses() async {
    final rows = await _remote.getCourses();
    final completed = await _remote.getCompletedLessonIds();

    return rows.map((row) {
      // Lesson ids arrive nested two levels deep (course -> modules ->
      // lessons); flatten to count totals and completions per course.
      final lessonIds = <String>[];
      for (final module in (row['course_modules'] as List? ?? [])) {
        for (final lesson in ((module as Map)['lessons'] as List? ?? [])) {
          lessonIds.add((lesson as Map)['id'] as String);
        }
      }

      return CourseSummary.fromMap(
        row,
        lessonCount: lessonIds.length,
        completedLessonCount:
            lessonIds.where((id) => completed.contains(id)).length,
      );
    }).toList();
  }

  @override
  Future<CourseDetail> getCourseDetail(String courseId) async {
    final courseRow = await _remote.getCourse(courseId);
    if (courseRow == null) {
      throw Exception('Course not found');
    }

    final moduleRows = await _remote.getModules(courseId);
    final completed = await _remote.getCompletedLessonIds();

    final modules = moduleRows.map((row) {
      final lessonRows =
          List<Map<String, dynamic>>.from((row['lessons'] as List? ?? []));
      // Nested selects come back unordered; sort by the position column.
      lessonRows.sort(
        (a, b) => ((a['position'] as int?) ?? 0)
            .compareTo((b['position'] as int?) ?? 0),
      );

      return CourseModule(
        id: row['id'] as String? ?? '',
        title: row['title'] as String? ?? 'Untitled',
        lessons: lessonRows
            .map((l) => Lesson.fromMap(
                  l,
                  completed: completed.contains(l['id'] as String?),
                ))
            .toList(),
      );
    }).toList();

    return CourseDetail(
      course: CourseSummaryRef.fromMap(courseRow),
      modules: modules,
    );
  }

  @override
  Future<void> markLessonCompleted(String lessonId) =>
      _remote.markLessonCompleted(lessonId);
}
