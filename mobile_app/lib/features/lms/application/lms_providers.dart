import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/supabase_client_provider.dart';
import '../data/datasources/lms_remote_datasource.dart';
import '../data/datasources/certificate_remote_datasource.dart';
import '../data/datasources/video_remote_datasource.dart';
import '../data/repositories/lms_repository_impl.dart';
import '../domain/entities/continue_course_item.dart';
import '../domain/entities/course_summary.dart';
import '../domain/entities/lesson.dart';
import '../domain/entities/certificate.dart';
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

/// Kept alive deliberately — see the note on the home providers.
///
/// This one is read by Home, the Courses tab AND Profile's enrolled
/// list, so without it a single scroll down and back up on Home cost
/// three screens their data and fired a refetch when any of them next
/// appeared. It is invalidated on pull-to-refresh, after a purchase,
/// and after an access grant, which are the moments it can actually
/// have changed.
final coursesProvider = FutureProvider.autoDispose<List<CourseSummary>>(
  (ref) {
    ref.keepAlive();
    return ref.watch(lmsRepositoryProvider).getCourses();
  },
);

/// Where the user last was in a course. Drives the resume card at the
/// top of Home.
///
/// keepAlive for the same reason coursesProvider has it: Home is a plain
/// ListView, so scrolling past this card unmounts it, and without the
/// hold it would refetch every time it came back into view. It is
/// invalidated on pull-to-refresh and whenever a lesson is opened, which
/// are the two moments its answer can have changed.
final continueCourseProvider =
    FutureProvider.autoDispose<ContinueCourseItem?>((ref) {
  ref.keepAlive();
  return ref.watch(lmsRepositoryProvider).getContinueCourse();
});

final courseDetailProvider =
    FutureProvider.autoDispose.family<CourseDetail, String>(
  (ref, courseId) => ref.watch(lmsRepositoryProvider).getCourseDetail(courseId),
);

// ── Certificates ─────────────────────────────────────────────────────────

final certificateDataSourceProvider =
    Provider<CertificateRemoteDataSource>((ref) {
  return CertificateRemoteDataSource(ref.watch(supabaseClientProvider));
});

/// How far through a course the learner is — the same arithmetic
/// issue_certificate() applies server-side, so the progress shown and
/// the certificate granted can never disagree.
final courseCompletionProvider =
    FutureProvider.autoDispose.family<CourseCompletion, String>(
  (ref, courseId) =>
      ref.watch(certificateDataSourceProvider).getCompletion(courseId),
);

final courseCertificateProvider =
    FutureProvider.autoDispose.family<Certificate?, String>(
  (ref, courseId) =>
      ref.watch(certificateDataSourceProvider).getCertificate(courseId),
);

final myCertificatesProvider =
    FutureProvider.autoDispose<List<Certificate>>(
  (ref) => ref.watch(certificateDataSourceProvider).getMyCertificates(),
);
