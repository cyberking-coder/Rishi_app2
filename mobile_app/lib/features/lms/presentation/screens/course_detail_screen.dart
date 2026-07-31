import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_theme.dart';
import '../../../access/application/access_providers.dart';
import '../../../audio/application/audio_providers.dart';
import '../../../audio/domain/entities/audio_track.dart';
import '../../../home/presentation/widgets/premium_lock.dart';
import '../../application/lms_providers.dart';
import '../../domain/entities/lesson.dart';

class CourseDetailScreen extends ConsumerStatefulWidget {
  final String courseId;
  final String title;

  const CourseDetailScreen({
    super.key,
    required this.courseId,
    required this.title,
  });

  @override
  ConsumerState<CourseDetailScreen> createState() => _CourseDetailScreenState();
}

class _CourseDetailScreenState extends ConsumerState<CourseDetailScreen> {
  bool _starting = false;

  Future<void> _openLesson(Lesson lesson, bool locked) async {
    if (locked) {
      showPremiumLockedMessage(context, ref);
      return;
    }

    if (!lesson.isPlayable) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("This lesson's content isn't available right now."),
        ),
      );
      return;
    }

    switch (lesson.type) {
      case LessonType.text:
        context.push('/lesson-text/${lesson.id}', extra: lesson);
        // Reading is the whole interaction for a text lesson, so opening
        // it counts as completing it.
        await _markComplete(lesson);
        return;

      case LessonType.video:
        // Unlike a text lesson, opening the player proves nothing — the
        // stream can still fail. The player reports back whether it
        // actually played, and only then does this count as complete.
        final played = await context.push<bool>(
          '/lesson-video/${lesson.id}',
          extra: lesson,
        );
        if (played == true) await _markComplete(lesson);
        return;

      case LessonType.audio:
        if (_starting) return;
        _starting = true;
        try {
          // Branches into the existing playback pipeline. Note the id
          // passed is the AUDIO's id, not the lesson's — that's what
          // issue-audio-license is keyed on.
          await ref.read(audioHandlerProvider).playSingleTrack(AudioTrack(
                id: lesson.audioId!,
                title: lesson.audioTitle ?? lesson.title,
                artist: lesson.audioArtist,
                coverArtUrl: lesson.audioCoverArtUrl,
                durationSeconds: lesson.audioDurationSeconds,
              ));
          if (mounted) context.push('/now-playing');
          await _markComplete(lesson);
        } catch (e) {
          if (!mounted) return;
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(e.toString())));
        } finally {
          _starting = false;
        }
    }
  }

  /// Best-effort: a progress write failing should never surface as an
  /// error over content that opened fine.
  Future<void> _markComplete(Lesson lesson) async {
    if (lesson.completed) return;
    try {
      await ref.read(lmsRepositoryProvider).markLessonCompleted(lesson.id);
      ref.invalidate(courseDetailProvider(widget.courseId));
      ref.invalidate(coursesProvider);
    } catch (_) {
      // ignored
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(courseDetailProvider(widget.courseId));
    final access = ref.watch(accessStateProvider).valueOrNull;

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: async.when(
        loading: () => const Center(
          child:
              CircularProgressIndicator(color: AppTheme.sage, strokeWidth: 2),
        ),
        error: (e, _) => SafeArea(
          child: Column(children: [
            _BackBar(title: widget.title),
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Text(
                    'Could not load this course.\n$e',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        color: AppTheme.textSecondary, height: 1.5),
                  ),
                ),
              ),
            ),
          ]),
        ),
        data: (detail) {
          final locked = detail.course.isPremium && access?.hasAccess != true;
          final next = detail.nextLesson;

          // Lessons are numbered 1..n across the whole course rather than
          // restarting inside each module, matching how a learner counts
          // their way through a programme.
          var lessonNumber = 0;

          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: _Hero(
                  coverUrl: detail.course.coverImageUrl,
                  onBack: () => Navigator.of(context).pop(),
                ),
              ),

              // Pulled up so the card overlaps the hero, the way the
              // reference layers its title card over the cover image.
              SliverToBoxAdapter(
                child: Transform.translate(
                  offset: const Offset(0, -28),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: _MetaCard(
                      title: detail.course.title,
                      description: detail.course.description,
                      lessonCount: detail.lessonCount,
                      completed: detail.completedCount,
                      progress: detail.progressFraction,
                      locked: locked,
                      nextLessonTitle: next?.title,
                      onPrimary: () {
                        if (locked) {
                          showPremiumLockedMessage(context, ref);
                        } else if (next != null) {
                          _openLesson(next, false);
                        }
                      },
                    ),
                  ),
                ),
              ),

              SliverToBoxAdapter(
                child: Transform.translate(
                  offset: const Offset(0, -14),
                  child: const Padding(
                    padding: EdgeInsets.fromLTRB(20, 0, 20, 10),
                    child: Text(
                      'Lessons',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ),
                ),
              ),

              if (detail.modules.isEmpty)
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 40, horizontal: 32),
                    child: Text(
                      'No lessons have been added to this course yet.',
                      textAlign: TextAlign.center,
                      style:
                          TextStyle(color: AppTheme.textSecondary, height: 1.5),
                    ),
                  ),
                ),

              for (final module in detail.modules) ...[
                // A single unnamed-feeling module is just "the course" —
                // only show module headers when there's more than one to
                // distinguish.
                if (detail.modules.length > 1)
                  SliverToBoxAdapter(
                    child: Transform.translate(
                      offset: const Offset(0, -14),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 10, 20, 8),
                        child: Text(
                          module.title.toUpperCase(),
                          style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.textSecondary,
                            letterSpacing: 0.6,
                          ),
                        ),
                      ),
                    ),
                  ),
                SliverList.separated(
                  itemCount: module.lessons.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (_, i) {
                    final lesson = module.lessons[i];
                    lessonNumber++;
                    return Transform.translate(
                      offset: const Offset(0, -14),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: _LessonTile(
                          number: lessonNumber,
                          lesson: lesson,
                          locked: locked,
                          onTap: () => _openLesson(lesson, locked),
                        ),
                      ),
                    );
                  },
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 10)),
              ],

              const SliverToBoxAdapter(child: SizedBox(height: 28)),
            ],
          );
        },
      ),
    );
  }
}

// ── Hero ─────────────────────────────────────────────────────────────

class _Hero extends StatelessWidget {
  final String? coverUrl;
  final VoidCallback onBack;

  const _Hero({required this.onBack, this.coverUrl});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 236,
      width: double.infinity,
      child: Stack(fit: StackFit.expand, children: [
        if (coverUrl != null && coverUrl!.isNotEmpty)
          Image.network(
            coverUrl!,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => const _HeroFallback(),
          )
        else
          const _HeroFallback(),

        // Scrim so the back button stays legible over a bright photo.
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withValues(alpha: 0.35),
                Colors.transparent,
              ],
              stops: const [0, 0.5],
            ),
          ),
        ),

        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
            child: Align(
              alignment: Alignment.topLeft,
              child: Material(
                color: Colors.white.withValues(alpha: 0.92),
                shape: const CircleBorder(),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: onBack,
                  child: const Padding(
                    padding: EdgeInsets.all(9),
                    child: Icon(Icons.arrow_back_rounded,
                        size: 20, color: AppTheme.textPrimary),
                  ),
                ),
              ),
            ),
          ),
        ),
      ]),
    );
  }
}

class _HeroFallback extends StatelessWidget {
  const _HeroFallback();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(gradient: AppTheme.sageGradient),
      child: const Center(
        child: Icon(Icons.self_improvement_rounded,
            color: Colors.white30, size: 64),
      ),
    );
  }
}

// ── Meta card ────────────────────────────────────────────────────────

class _MetaCard extends StatelessWidget {
  final String title;
  final String? description;
  final int lessonCount;
  final int completed;
  final double progress;
  final bool locked;
  final String? nextLessonTitle;
  final VoidCallback onPrimary;

  const _MetaCard({
    required this.title,
    required this.lessonCount,
    required this.completed,
    required this.progress,
    required this.locked,
    required this.onPrimary,
    this.description,
    this.nextLessonTitle,
  });

  @override
  Widget build(BuildContext context) {
    final started = completed > 0;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusCard),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 19,
            fontWeight: FontWeight.w800,
            color: AppTheme.textPrimary,
            height: 1.3,
          ),
        ),
        if (description != null && description!.trim().isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            description!,
            style: const TextStyle(
              fontSize: 13,
              color: AppTheme.textSecondary,
              height: 1.55,
            ),
          ),
        ],
        const SizedBox(height: 14),

        Row(children: [
          const Icon(Icons.play_lesson_outlined, size: 15, color: AppTheme.sage),
          const SizedBox(width: 6),
          Text(
            '$lessonCount ${lessonCount == 1 ? "lesson" : "lessons"}',
            style: const TextStyle(
              fontSize: 12.5,
              color: AppTheme.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (locked) ...[
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
              decoration: BoxDecoration(
                color: AppTheme.sandSoft,
                borderRadius: BorderRadius.circular(AppTheme.radiusPill),
              ),
              child: const Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.lock_rounded, size: 11, color: AppTheme.clay),
                SizedBox(width: 4),
                Text(
                  'Members only',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.clay,
                  ),
                ),
              ]),
            ),
          ],
        ]),

        if (started && !locked) ...[
          const SizedBox(height: 14),
          Row(children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: progress,
                  backgroundColor: AppTheme.sageSoft,
                  valueColor: const AlwaysStoppedAnimation(AppTheme.sage),
                  minHeight: 6,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              '$completed/$lessonCount',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppTheme.sage,
              ),
            ),
          ]),
        ],

        if (locked || nextLessonTitle != null) ...[
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: onPrimary,
              child: Text(
                locked
                    ? 'Unlock this course'
                    : started
                        ? 'Continue learning'
                        : 'Start course',
              ),
            ),
          ),
        ],
      ]),
    );
  }
}

// ── Lesson row ───────────────────────────────────────────────────────

class _LessonTile extends StatelessWidget {
  final int number;
  final Lesson lesson;
  final bool locked;
  final VoidCallback onTap;

  const _LessonTile({
    required this.number,
    required this.lesson,
    required this.locked,
    required this.onTap,
  });

  IconData get _typeIcon {
    switch (lesson.type) {
      case LessonType.audio:
        return Icons.headphones_rounded;
      case LessonType.video:
        return Icons.play_arrow_rounded;
      case LessonType.text:
        return Icons.article_rounded;
    }
  }

  String get _subtitle {
    if (!lesson.isPlayable) return 'Unavailable';
    switch (lesson.type) {
      case LessonType.audio:
        final secs = lesson.audioDurationSeconds;
        if (secs == null) return 'Audio';
        return 'Audio · ${(secs / 60).ceil()} min';
      case LessonType.video:
        return 'Video';
      case LessonType.text:
        return 'Reading';
    }
  }

  @override
  Widget build(BuildContext context) {
    final done = lesson.completed && !locked;

    return Material(
      color: AppTheme.surfaceCream,
      borderRadius: BorderRadius.circular(AppTheme.radiusRow),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.radiusRow),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          child: Row(children: [
            // Leading badge shows state first (locked / done) and falls
            // back to the media type — the state is what decides whether
            // tapping does anything.
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: locked
                    ? AppTheme.sandSoft
                    : done
                        ? AppTheme.sage
                        : AppTheme.surface,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                locked
                    ? Icons.lock_rounded
                    : done
                        ? Icons.check_rounded
                        : _typeIcon,
                size: 19,
                color: locked
                    ? AppTheme.clay
                    : done
                        ? Colors.white
                        : AppTheme.sage,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$number. ${lesson.title}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      height: 1.3,
                      color: lesson.isPlayable
                          ? AppTheme.textPrimary
                          : AppTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    _subtitle,
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              Icons.chevron_right_rounded,
              size: 20,
              color: AppTheme.textSecondary.withValues(alpha: 0.6),
            ),
          ]),
        ),
      ),
    );
  }
}

// ── Shared ───────────────────────────────────────────────────────────

class _BackBar extends StatelessWidget {
  final String title;
  const _BackBar({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Row(children: [
        IconButton(
          icon: const Icon(Icons.arrow_back_rounded, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        Expanded(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            ),
          ),
        ),
      ]),
    );
  }
}
