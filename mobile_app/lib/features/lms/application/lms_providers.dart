import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/supabase_client_provider.dart';
import '../data/datasources/lms_remote_datasource.dart';
import '../data/datasources/quiz_remote_datasource.dart';
import '../data/datasources/video_remote_datasource.dart';
import '../data/repositories/lms_repository_impl.dart';
import '../domain/entities/course_summary.dart';
import '../domain/entities/lesson.dart';
import '../domain/entities/quiz.dart';
import '../domain/repositories/lms_repository.dart';

final lmsRemoteDataSourceProvider = Provider<LmsRemoteDataSource>((ref) {
  return LmsRemoteDataSource(ref.watch(supabaseClientProvider));
});

final videoRemoteDataSourceProvider = Provider<VideoRemoteDataSource>((ref) {
  return VideoRemoteDataSource(ref.watch(supabaseClientProvider));
});

final lmsRepositoryProvider = Provider<LmsRepository>((ref) {
  return LmsRepositoryImpl(ref.watch(lmsRemoteDataSourceProvider));
});

final coursesProvider = FutureProvider.autoDispose<List<CourseSummary>>(
  (ref) => ref.watch(lmsRepositoryProvider).getCourses(),
);

final courseDetailProvider =
    FutureProvider.autoDispose.family<CourseDetail, String>(
  (ref, courseId) => ref.watch(lmsRepositoryProvider).getCourseDetail(courseId),
);

// ── Quizzes & certificates (Phase 5) ─────────────────────────────────────

final quizRemoteDataSourceProvider = Provider<QuizRemoteDataSource>((ref) {
  return QuizRemoteDataSource(ref.watch(supabaseClientProvider));
});

/// Every quiz in a course, with the caller's attempt history folded in.
///
/// Depends on courseDetailProvider for the lesson ids rather than
/// re-querying them: a quiz can hang off a lesson, and the course detail
/// already knows which lessons exist.
final courseQuizzesProvider =
    FutureProvider.autoDispose.family<List<Quiz>, String>(
  (ref, courseId) async {
    final detail = await ref.watch(courseDetailProvider(courseId).future);
    final lessonIds = [
      for (final module in detail.modules)
        for (final lesson in module.lessons) lesson.id,
    ];
    return ref
        .watch(quizRemoteDataSourceProvider)
        .getCourseQuizzes(courseId, lessonIds);
  },
);

/// How far through a course the learner is, counting lessons AND quizzes
/// — the same arithmetic issue_certificate() applies server-side, so the
/// progress shown and the certificate granted can never disagree.
final courseCompletionProvider =
    FutureProvider.autoDispose.family<CourseCompletion, String>(
  (ref, courseId) =>
      ref.watch(quizRemoteDataSourceProvider).getCompletion(courseId),
);

final courseCertificateProvider =
    FutureProvider.autoDispose.family<Certificate?, String>(
  (ref, courseId) =>
      ref.watch(quizRemoteDataSourceProvider).getCertificate(courseId),
);

final myCertificatesProvider =
    FutureProvider.autoDispose<List<Certificate>>(
  (ref) => ref.watch(quizRemoteDataSourceProvider).getMyCertificates(),
);
