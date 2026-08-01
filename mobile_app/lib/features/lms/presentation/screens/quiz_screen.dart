import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_theme.dart';
import '../../application/lms_providers.dart';
import '../../domain/entities/quiz.dart';

/// Take a quiz, one question per screen, then see how it went.
///
/// Grading is a single round trip to submit_quiz_attempt at the end. The
/// device never holds the answer key — it can't, since is_correct isn't
/// readable by learners — so there is no client-side scoring to keep in
/// step with the server's, and no way to peek.
class QuizScreen extends ConsumerStatefulWidget {
  final Quiz quiz;

  const QuizScreen({super.key, required this.quiz});

  @override
  ConsumerState<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends ConsumerState<QuizScreen> {
  /// questionId -> chosen optionId.
  final Map<String, String> _answers = {};
  int _index = 0;
  bool _submitting = false;
  QuizResult? _result;
  String? _error;

  Quiz get quiz => widget.quiz;
  List<QuizQuestion> get questions => quiz.questions;

  Future<void> _submit() async {
    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      final result = await ref
          .read(quizRemoteDataSourceProvider)
          .submitAttempt(quiz.id, _answers);

      if (!mounted) return;
      setState(() {
        _result = result;
        _submitting = false;
      });

      // Passing can complete the course, which is what makes a
      // certificate claimable — so drop the cached answers to both
      // rather than leaving the course screen showing stale progress.
      ref.invalidate(courseQuizzesProvider);
      ref.invalidate(courseCompletionProvider);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Column(
          children: [
            _Header(
              title: quiz.title,
              // Once graded, the progress bar has done its job — the
              // result view is a single page.
              progress: _result != null || questions.isEmpty
                  ? null
                  : (_index + 1) / questions.length,
              subtitle: _result != null
                  ? null
                  : 'Question ${_index + 1} of ${questions.length}',
            ),
            Expanded(
              child: _result != null
                  ? _ResultView(quiz: quiz, result: _result!)
                  : questions.isEmpty
                      ? const _EmptyQuiz()
                      : _questionView(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _questionView() {
    final question = questions[_index];
    final chosen = _answers[question.id];
    final isLast = _index == questions.length - 1;
    // Every question must be answered before submitting. An unanswered
    // one scores zero server-side, so letting it through would quietly
    // cost marks for a tap the learner didn't know they'd missed.
    final allAnswered = questions.every((q) => _answers.containsKey(q.id));

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
            children: [
              Text(
                question.prompt,
                style: const TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 20),
              for (final option in question.options)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _OptionTile(
                    label: option.label,
                    selected: chosen == option.id,
                    onTap: () => setState(
                      () => _answers[question.id] = option.id,
                    ),
                  ),
                ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  style: const TextStyle(color: AppTheme.clay, fontSize: 13),
                ),
              ],
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: Row(
            children: [
              if (_index > 0)
                TextButton(
                  onPressed: _submitting
                      ? null
                      : () => setState(() => _index -= 1),
                  child: const Text('Back'),
                ),
              const Spacer(),
              FilledButton(
                onPressed: _submitting || chosen == null
                    ? null
                    : isLast
                        ? (allAnswered ? _submit : null)
                        : () => setState(() => _index += 1),
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.sage,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 28, vertical: 14),
                ),
                child: Text(
                  _submitting
                      ? 'Checking…'
                      : isLast
                          ? 'Submit'
                          : 'Next',
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.title, this.subtitle, this.progress});

  final String title;
  final String? subtitle;
  final double? progress;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 6, 20, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.close_rounded, size: 22),
                color: AppTheme.textSecondary,
                onPressed: () => Navigator.of(context).pop(),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    if (subtitle != null)
                      Text(
                        subtitle!,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          if (progress != null) ...[
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 5,
                  backgroundColor: AppTheme.border,
                  valueColor:
                      const AlwaysStoppedAnimation<Color>(AppTheme.sage),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _OptionTile extends StatelessWidget {
  const _OptionTile({
    required this.label,
    required this.selected,
    this.onTap,
    this.state,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;

  /// Set only in the result view: true = this was the right answer,
  /// false = this was chosen and wrong.
  final bool? state;

  @override
  Widget build(BuildContext context) {
    final correct = state == true;
    final wrong = state == false;

    final borderColor = correct
        ? const Color(0xFF2E9E6B)
        : wrong
            ? AppTheme.clay
            : selected
                ? AppTheme.sage
                : AppTheme.border;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: correct
              ? const Color(0x142E9E6B)
              : wrong
                  ? AppTheme.clay.withValues(alpha: 0.08)
                  : selected
                      ? AppTheme.sageSoft
                      : AppTheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: borderColor,
            width: selected || state != null ? 1.6 : 1,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 15,
                  color: AppTheme.textPrimary,
                  height: 1.3,
                ),
              ),
            ),
            if (correct)
              const Icon(Icons.check_circle_rounded,
                  size: 20, color: Color(0xFF2E9E6B))
            else if (wrong)
              const Icon(Icons.cancel_rounded, size: 20, color: AppTheme.clay)
            else if (selected)
              const Icon(Icons.radio_button_checked,
                  size: 20, color: AppTheme.sage),
          ],
        ),
      ),
    );
  }
}

class _ResultView extends StatelessWidget {
  const _ResultView({required this.quiz, required this.result});

  final Quiz quiz;
  final QuizResult result;

  @override
  Widget build(BuildContext context) {
    final byQuestion = {for (final r in result.results) r.questionId: r};

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: result.passed ? AppTheme.sageSoft : AppTheme.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: result.passed ? AppTheme.sage : AppTheme.border,
            ),
          ),
          child: Column(
            children: [
              Icon(
                result.passed
                    ? Icons.workspace_premium_rounded
                    : Icons.refresh_rounded,
                size: 40,
                color: result.passed ? AppTheme.sage : AppTheme.textSecondary,
              ),
              const SizedBox(height: 10),
              Text(
                result.passed ? 'Passed' : 'Not quite yet',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${result.correctCount} of ${result.questionCount} correct '
                '· ${result.scorePercent}%',
                style: const TextStyle(
                  fontSize: 14,
                  color: AppTheme.textSecondary,
                ),
              ),
              if (!result.passed) ...[
                const SizedBox(height: 8),
                Text(
                  'You need ${result.passPercent}% to pass. Review the '
                  'answers below and try again.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppTheme.textSecondary,
                    height: 1.4,
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 20),
        for (var i = 0; i < quiz.questions.length; i++)
          _ReviewCard(
            index: i + 1,
            question: quiz.questions[i],
            result: byQuestion[quiz.questions[i].id],
          ),
        const SizedBox(height: 8),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(result.passed),
          style: FilledButton.styleFrom(
            backgroundColor: AppTheme.sage,
            minimumSize: const Size.fromHeight(50),
          ),
          child: const Text('Done'),
        ),
      ],
    );
  }
}

class _ReviewCard extends StatelessWidget {
  const _ReviewCard({
    required this.index,
    required this.question,
    this.result,
  });

  final int index;
  final QuizQuestion question;
  final QuizQuestionResult? result;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$index. ${question.prompt}',
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 10),
          for (final option in question.options)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _OptionTile(
                label: option.label,
                selected: result?.chosenOptionId == option.id,
                // Right answers are always marked, so a learner who got
                // it wrong still leaves knowing what was right.
                state: option.id == result?.correctOptionId
                    ? true
                    : (option.id == result?.chosenOptionId &&
                            result?.correct == false)
                        ? false
                        : null,
              ),
            ),
          if (result?.explanation != null &&
              result!.explanation!.trim().isNotEmpty)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(top: 2),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.surfaceCream,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                result!.explanation!,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppTheme.textSecondary,
                  height: 1.45,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _EmptyQuiz extends StatelessWidget {
  const _EmptyQuiz();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Text(
          "This quiz doesn't have any questions yet.",
          textAlign: TextAlign.center,
          style: TextStyle(color: AppTheme.textSecondary),
        ),
      ),
    );
  }
}
