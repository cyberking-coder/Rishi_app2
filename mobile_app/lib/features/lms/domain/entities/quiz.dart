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

  const Certificate({
    required this.id,
    required this.certificateNumber,
    required this.courseTitle,
    required this.issuedAt,
    this.recipientName,
    this.revokedAt,
  });

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
