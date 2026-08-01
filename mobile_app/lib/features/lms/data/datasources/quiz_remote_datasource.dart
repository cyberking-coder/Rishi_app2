import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/entities/quiz.dart';

/// Reads quizzes and certificates, and submits attempts.
///
/// Grading never happens here. `submit_quiz_attempt` scores server-side
/// and returns the result — the device sends what was chosen and is told
/// what was right, in that order. It has no way to learn the answers
/// first: `quiz_options.is_correct` is withheld by a column-level grant,
/// so asking for it errors rather than answering.
class QuizRemoteDataSource {
  final SupabaseClient _client;

  QuizRemoteDataSource(this._client);

  /// Every quiz in a course — the course's final assessment plus any
  /// per-lesson checks — with the caller's own attempt history folded in.
  Future<List<Quiz>> getCourseQuizzes(
    String courseId,
    List<String> lessonIds,
  ) async {
    final filter = lessonIds.isEmpty
        ? 'course_id.eq.$courseId'
        : 'course_id.eq.$courseId,lesson_id.in.(${lessonIds.join(',')})';

    final rows = await _client
        .from('quizzes')
        .select(
          'id, title, description, pass_percent, max_attempts, position, '
          'course_id, lesson_id, '
          'quiz_questions(id, prompt, position, '
          'quiz_options(id, label, position))',
        )
        .or(filter)
        .order('position', ascending: true);

    final quizzes = List<Map<String, dynamic>>.from(rows as List);
    if (quizzes.isEmpty) return const [];

    final history = await _attemptHistory(
      quizzes.map((q) => q['id'] as String).toList(),
    );

    return quizzes.map((row) {
      final stats = history[row['id'] as String];
      return Quiz.fromMap(
        row,
        bestScorePercent: stats?.bestScore,
        passed: stats?.passed ?? false,
        attemptsUsed: stats?.attempts ?? 0,
      );
    }).toList();
  }

  /// Which lesson each quiz belongs to, so the course screen can show a
  /// check under the right lesson. Course-level quizzes map to null.
  Future<Map<String, String?>> getQuizLessonMap(
    String courseId,
    List<String> lessonIds,
  ) async {
    final filter = lessonIds.isEmpty
        ? 'course_id.eq.$courseId'
        : 'course_id.eq.$courseId,lesson_id.in.(${lessonIds.join(',')})';

    final rows =
        await _client.from('quizzes').select('id, lesson_id').or(filter);

    return {
      for (final row in rows as List)
        (row as Map)['id'] as String: row['lesson_id'] as String?,
    };
  }

  Future<Map<String, _AttemptStats>> _attemptHistory(
    List<String> quizIds,
  ) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null || quizIds.isEmpty) return {};

    // RLS already scopes attempts to the caller, so no user filter is
    // needed — the same reasoning as getPurchasedCourseIds.
    final rows = await _client
        .from('quiz_attempts')
        .select('quiz_id, score_percent, passed')
        .inFilter('quiz_id', quizIds);

    final stats = <String, _AttemptStats>{};
    for (final row in rows as List) {
      final map = row as Map;
      final quizId = map['quiz_id'] as String;
      final score = (map['score_percent'] as num?)?.toInt() ?? 0;
      final passed = map['passed'] as bool? ?? false;

      final existing = stats[quizId];
      stats[quizId] = _AttemptStats(
        // Best, not latest: a pass already earned isn't undone by a
        // worse retake, and course completion asks whether they have
        // ever passed.
        bestScore: existing == null ? score : (score > existing.bestScore ? score : existing.bestScore),
        passed: (existing?.passed ?? false) || passed,
        attempts: (existing?.attempts ?? 0) + 1,
      );
    }
    return stats;
  }

  /// Submits answers as `{questionId: optionId}` and returns the grade.
  Future<QuizResult> submitAttempt(
    String quizId,
    Map<String, String> answers,
  ) async {
    final response = await _client.rpc(
      'submit_quiz_attempt',
      params: {'p_quiz_id': quizId, 'p_answers': answers},
    );

    return QuizResult.fromMap(Map<String, dynamic>.from(response as Map));
  }

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

class _AttemptStats {
  final int bestScore;
  final bool passed;
  final int attempts;

  const _AttemptStats({
    required this.bestScore,
    required this.passed,
    required this.attempts,
  });
}
