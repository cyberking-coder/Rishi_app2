/// One selectable answer. Deliberately has no `isCorrect` — the column
/// is withheld from learners by a column-level grant, so the answer key
/// never travels to the device and can't be read out of the app.
/// Correctness only ever arrives as part of a graded [QuizResult].
class QuizOption {
  final String id;
  final String label;

  const QuizOption({required this.id, required this.label});

  factory QuizOption.fromMap(Map<String, dynamic> map) => QuizOption(
        id: map['id'] as String? ?? '',
        label: map['label'] as String? ?? '',
      );
}

class QuizQuestion {
  final String id;
  final String prompt;
  final List<QuizOption> options;

  const QuizQuestion({
    required this.id,
    required this.prompt,
    this.options = const [],
  });

  factory QuizQuestion.fromMap(Map<String, dynamic> map) {
    final options = (map['quiz_options'] as List? ?? [])
        .cast<Map<String, dynamic>>()
        .map(QuizOption.fromMap)
        .toList();

    // Ordered here rather than trusted from the server: PostgREST returns
    // embedded rows in primary-key order, so without this they'd appear
    // in creation order rather than the order the admin arranged.
    final positions = {
      for (final row in (map['quiz_options'] as List? ?? []))
        (row as Map)['id'] as String: (row['position'] as num?)?.toInt() ?? 0,
    };
    options.sort(
      (a, b) => (positions[a.id] ?? 0).compareTo(positions[b.id] ?? 0),
    );

    return QuizQuestion(
      id: map['id'] as String? ?? '',
      prompt: map['prompt'] as String? ?? '',
      options: options,
    );
  }
}

class Quiz {
  final String id;
  final String title;
  final String? description;
  final int passPercent;

  /// null means unlimited retakes.
  final int? maxAttempts;
  final List<QuizQuestion> questions;

  /// The learner's best score so far, and whether they've ever passed.
  /// Both derived from their attempt history, so a pass survives a later
  /// worse attempt — course completion asks "have they ever passed", not
  /// "did the last try succeed".
  final int? bestScorePercent;
  final bool passed;
  final int attemptsUsed;

  const Quiz({
    required this.id,
    required this.title,
    required this.passPercent,
    this.description,
    this.maxAttempts,
    this.questions = const [],
    this.bestScorePercent,
    this.passed = false,
    this.attemptsUsed = 0,
  });

  bool get hasAttemptsLeft =>
      maxAttempts == null || attemptsUsed < maxAttempts!;

  factory Quiz.fromMap(
    Map<String, dynamic> map, {
    int? bestScorePercent,
    bool passed = false,
    int attemptsUsed = 0,
  }) {
    final questions = (map['quiz_questions'] as List? ?? [])
        .cast<Map<String, dynamic>>()
        .toList();
    questions.sort((a, b) {
      final pa = (a['position'] as num?)?.toInt() ?? 0;
      final pb = (b['position'] as num?)?.toInt() ?? 0;
      return pa.compareTo(pb);
    });

    return Quiz(
      id: map['id'] as String? ?? '',
      title: map['title'] as String? ?? 'Quiz',
      description: map['description'] as String?,
      passPercent: (map['pass_percent'] as num?)?.toInt() ?? 70,
      maxAttempts: (map['max_attempts'] as num?)?.toInt(),
      questions: questions.map(QuizQuestion.fromMap).toList(),
      bestScorePercent: bestScorePercent,
      passed: passed,
      attemptsUsed: attemptsUsed,
    );
  }
}

/// How one question was graded. Built from submit_quiz_attempt's reply —
/// the first and only point at which the device learns what was correct.
class QuizQuestionResult {
  final String questionId;
  final String? chosenOptionId;
  final String? correctOptionId;
  final bool correct;
  final String? explanation;

  const QuizQuestionResult({
    required this.questionId,
    required this.correct,
    this.chosenOptionId,
    this.correctOptionId,
    this.explanation,
  });

  factory QuizQuestionResult.fromMap(Map<String, dynamic> map) =>
      QuizQuestionResult(
        questionId: map['question_id'] as String? ?? '',
        chosenOptionId: map['chosen_option_id'] as String?,
        correctOptionId: map['correct_option_id'] as String?,
        correct: map['correct'] as bool? ?? false,
        explanation: map['explanation'] as String?,
      );
}

class QuizResult {
  final int scorePercent;
  final int correctCount;
  final int questionCount;
  final int passPercent;
  final bool passed;
  final List<QuizQuestionResult> results;

  const QuizResult({
    required this.scorePercent,
    required this.correctCount,
    required this.questionCount,
    required this.passPercent,
    required this.passed,
    this.results = const [],
  });

  factory QuizResult.fromMap(Map<String, dynamic> map) => QuizResult(
        scorePercent: (map['score_percent'] as num?)?.toInt() ?? 0,
        correctCount: (map['correct_count'] as num?)?.toInt() ?? 0,
        questionCount: (map['question_count'] as num?)?.toInt() ?? 0,
        passPercent: (map['pass_percent'] as num?)?.toInt() ?? 70,
        passed: map['passed'] as bool? ?? false,
        results: (map['results'] as List? ?? [])
            .cast<Map<String, dynamic>>()
            .map(QuizQuestionResult.fromMap)
            .toList(),
      );
}

/// What a certificate says. Course title and recipient name are snapshots
/// taken when it was issued, not live joins — a course renamed afterwards
/// must not rewrite credentials already awarded.
class Certificate {
  final String id;
  final String certificateNumber;
  final String courseTitle;
  final String? recipientName;
  final DateTime issuedAt;
  final DateTime? revokedAt;

  /// The admin's own artwork for this course, if they uploaded any, and
  /// where the recipient's name goes on it. Read from the course rather
  /// than snapshotted onto the certificate: the design is presentation,
  /// so re-uploading better artwork should improve every certificate
  /// already issued — unlike the course TITLE, which is a claim about
  /// what was earned and must never change retroactively.
  final CertificateLayout? layout;

  const Certificate({
    required this.id,
    required this.certificateNumber,
    required this.courseTitle,
    required this.issuedAt,
    this.recipientName,
    this.revokedAt,
    this.layout,
  });

  Certificate withLayout(CertificateLayout? value) => Certificate(
        id: id,
        certificateNumber: certificateNumber,
        courseTitle: courseTitle,
        recipientName: recipientName,
        issuedAt: issuedAt,
        revokedAt: revokedAt,
        layout: value,
      );

  bool get isValid => revokedAt == null;

  factory Certificate.fromMap(Map<String, dynamic> map) => Certificate(
        id: map['id'] as String? ?? '',
        certificateNumber: map['certificate_number'] as String? ?? '',
        courseTitle: map['course_title'] as String? ?? 'Course',
        recipientName: map['recipient_name'] as String?,
        issuedAt:
            DateTime.tryParse(map['issued_at'] as String? ?? '')?.toLocal() ??
                DateTime.now(),
        revokedAt: map['revoked_at'] == null
            ? null
            : DateTime.tryParse(map['revoked_at'] as String)?.toLocal(),
      );
}

/// Admin-uploaded certificate artwork and where the name is printed on
/// it. All positions are PERCENTAGES of the image, never pixels, so one
/// template lands correctly on any screen and at any export resolution.
class CertificateLayout {
  final String templateUrl;

  /// 0 = top edge, 100 = bottom edge. The name's vertical centre.
  final double topPercent;

  /// 0 = left edge, 100 = right edge. The name's horizontal centre.
  final double leftPercent;

  /// Font size as a percentage of the image's width.
  final double sizePercent;
  final int colorValue;

  const CertificateLayout({
    required this.templateUrl,
    required this.topPercent,
    required this.leftPercent,
    required this.sizePercent,
    required this.colorValue,
  });

  static CertificateLayout? fromMap(Map<String, dynamic>? map) {
    final url = map?['certificate_template_url'] as String?;
    if (map == null || url == null || url.isEmpty) return null;

    return CertificateLayout(
      templateUrl: url,
      topPercent: (map['certificate_name_top'] as num?)?.toDouble() ?? 52,
      leftPercent: (map['certificate_name_left'] as num?)?.toDouble() ?? 50,
      sizePercent: (map['certificate_name_size'] as num?)?.toDouble() ?? 7,
      colorValue: _parseHex(map['certificate_name_color'] as String?),
    );
  }

  /// '#1A1A1A' -> 0xFF1A1A1A. Falls back to near-black rather than
  /// throwing: a malformed colour should print a readable name, not
  /// break the certificate.
  static int _parseHex(String? hex) {
    if (hex == null) return 0xFF1A1A1A;
    final cleaned = hex.replaceAll('#', '').trim();
    if (cleaned.length != 6) return 0xFF1A1A1A;
    return int.tryParse('FF$cleaned', radix: 16) ?? 0xFF1A1A1A;
  }
}

/// Progress toward a certificate, straight from course_completion_state.
class CourseCompletion {
  final int lessonCount;
  final int lessonsCompleted;
  final int quizCount;
  final int quizzesPassed;
  final bool complete;

  const CourseCompletion({
    this.lessonCount = 0,
    this.lessonsCompleted = 0,
    this.quizCount = 0,
    this.quizzesPassed = 0,
    this.complete = false,
  });

  factory CourseCompletion.fromMap(Map<String, dynamic> map) =>
      CourseCompletion(
        lessonCount: (map['lesson_count'] as num?)?.toInt() ?? 0,
        lessonsCompleted: (map['lessons_completed'] as num?)?.toInt() ?? 0,
        quizCount: (map['quiz_count'] as num?)?.toInt() ?? 0,
        quizzesPassed: (map['quizzes_passed'] as num?)?.toInt() ?? 0,
        complete: map['complete'] as bool? ?? false,
      );

  /// Everything that has to be done, and how much of it is.
  int get totalSteps => lessonCount + quizCount;
  int get completedSteps => lessonsCompleted + quizzesPassed;

  double get fraction => totalSteps == 0 ? 0 : completedSteps / totalSteps;
}
