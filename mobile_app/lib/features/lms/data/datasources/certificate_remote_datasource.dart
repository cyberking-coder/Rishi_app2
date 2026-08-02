import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/entities/certificate.dart';

/// Reads course completion and certificates.
///
/// Completion is computed server-side by course_completion_state(), the
/// same function issue_certificate() checks before granting — so what a
/// learner is shown and what they are granted cannot disagree.
class CertificateRemoteDataSource {
  final SupabaseClient _client;

  CertificateRemoteDataSource(this._client);

  Future<CourseCompletion> getCompletion(String courseId) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return const CourseCompletion();

    final response = await _client.rpc(
      'course_completion_state',
      params: {'p_user_id': userId, 'p_course_id': courseId},
    );

    if (response is! Map) return const CourseCompletion();
    return CourseCompletion.fromMap(Map<String, dynamic>.from(response));
  }

  /// Claims the certificate for a completed course.
  ///
  /// Idempotent server-side, so calling it on a course already certified
  /// returns the existing one rather than minting a second. Throws when
  /// the course isn't finished — callers check completion first rather
  /// than using the exception as control flow.
  Future<Certificate> issueCertificate(String courseId) async {
    final response = await _client
        .rpc('issue_certificate', params: {'p_course_id': courseId});

    return Certificate.fromMap(Map<String, dynamic>.from(response as Map))
        .withLayout(await _layoutFor(courseId));
  }

  Future<Certificate?> getCertificate(String courseId) async {
    final row = await _client
        .from('certificates')
        .select('*')
        .eq('course_id', courseId)
        .maybeSingle();

    if (row == null) return null;
    return Certificate.fromMap(row)
        .withLayout(await _layoutFor(courseId));
  }

  /// The course's certificate artwork, if the admin uploaded any.
  ///
  /// Fetched separately rather than embedded on the certificate query:
  /// certificates has no FK relationship PostgREST can traverse to
  /// courses' design columns without an embed, and an embed that fails
  /// would take the certificate itself down with it.
  Future<CertificateLayout?> _layoutFor(String courseId) async {
    try {
      final row = await _client
          .from('courses')
          .select(
            'certificate_template_url, certificate_name_top, '
            'certificate_name_left, certificate_name_size, '
            'certificate_name_color',
          )
          .eq('id', courseId)
          .maybeSingle();

      return CertificateLayout.fromMap(row);
    } catch (_) {
      // No artwork is a perfectly good outcome — the app draws its own
      // certificate. A failure here must not cost the learner theirs.
      return null;
    }
  }

  Future<List<Certificate>> getMyCertificates() async {
    final rows = await _client
        .from('certificates')
        .select('*')
        .order('issued_at', ascending: false);

    return List<Map<String, dynamic>>.from(rows as List)
        .map(Certificate.fromMap)
        .toList();
  }
}
