import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/supabase_client_provider.dart';
import '../data/datasources/lms_remote_datasource.dart';
import '../data/repositories/lms_repository_impl.dart';
import '../domain/entities/course_summary.dart';
import '../domain/entities/lesson.dart';
import '../domain/repositories/lms_repository.dart';

final lmsRemoteDataSourceProvider = Provider<LmsRemoteDataSource>((ref) {
  return LmsRemoteDataSource(ref.watch(supabaseClientProvider));
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
