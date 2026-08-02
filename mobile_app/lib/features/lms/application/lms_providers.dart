import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/supabase_client_provider.dart';
import '../data/datasources/lms_remote_datasource.dart';
import '../data/datasources/certificate_remote_datasource.dart';
import '../data/datasources/video_remote_datasource.dart';
import '../data/repositories/lms_repository_impl.dart';
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

final coursesProvider = FutureProvider.autoDispose<List<CourseSummary>>(
  (ref) => ref.watch(lmsRepositoryProvider).getCourses(),
);

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
