import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../access/application/access_providers.dart';
import '../../../audio/application/audio_providers.dart';
import '../../../audio/domain/entities/audio_track.dart';
import '../../../home/presentation/widgets/premium_lock.dart';
import '../../application/lms_providers.dart';
import '../../domain/entities/lesson.dart';

const _kBg = Color(0xFF12082E);
const _kSurface = Color(0xFF1C1040);
const _kAccent = Color(0xFF8B5CF6);
const _kTextSec = Color(0xFFB0A8CC);

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
          content: Text('This lesson\'s content isn\'t available right now.'),
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
        context.push('/lesson-video/${lesson.id}', extra: lesson);
        await _markComplete(lesson);
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
      backgroundColor: _kBg,
      body: SafeArea(
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_ios,
                    color: Colors.white, size: 18),
                onPressed: () => Navigator.of(context).pop(),
              ),
              Expanded(
                child: Text(widget.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white)),
              ),
            ]),
          ),
          Expanded(
            child: async.when(
              loading: () => const Center(
                  child: CircularProgressIndicator(
                      color: _kAccent, strokeWidth: 2)),
              error: (e, _) => Center(
                child: Text('Could not load this course.\n$e',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: _kTextSec)),
              ),
              data: (detail) {
                final locked =
                    detail.course.isPremium && access?.hasAccess != true;

                return ListView(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                  children: [
                    if (detail.course.description != null) ...[
                      Text(detail.course.description!,
                          style: const TextStyle(
                              fontSize: 13, color: _kTextSec, height: 1.5)),
                      const SizedBox(height: 16),
                    ],

                    if (locked)
                      _LockedBanner(onTap: () => showPremiumLockedMessage(context, ref))
                    else if (detail.lessonCount > 0)
                      _ProgressBanner(
                        completed: detail.completedCount,
                        total: detail.lessonCount,
                        fraction: detail.progressFraction,
                      ),

                    const SizedBox(height: 16),

                    for (final module in detail.modules) ...[
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8, top: 8),
                        child: Text(module.title,
                            style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: Colors.white)),
                      ),
                      for (final lesson in module.lessons)
                        _LessonTile(
                          lesson: lesson,
                          locked: locked,
                          onTap: () => _openLesson(lesson, locked),
                        ),
                      const SizedBox(height: 8),
                    ],

                    if (detail.modules.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 32),
                        child: Text('No lessons yet.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: _kTextSec)),
                      ),
                  ],
                );
              },
            ),
          ),
        ]),
      ),
    );
  }
}

class _ProgressBanner extends StatelessWidget {
  final int completed;
  final int total;
  final double fraction;

  const _ProgressBanner({
    required this.completed,
    required this.total,
    required this.fraction,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _kSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _kAccent.withValues(alpha: 0.3)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('$completed of $total lessons complete',
            style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.white)),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: fraction,
            backgroundColor: Colors.white.withValues(alpha: 0.1),
            valueColor: const AlwaysStoppedAnimation(_kAccent),
            minHeight: 4,
          ),
        ),
      ]),
    );
  }
}

class _LockedBanner extends StatelessWidget {
  final VoidCallback onTap;
  const _LockedBanner({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _kSurface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _kAccent.withValues(alpha: 0.4)),
        ),
        child: Row(children: [
          const Icon(Icons.lock_outline, color: _kAccent, size: 18),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'This course is for members with active access.',
              style: TextStyle(fontSize: 13, color: Colors.white),
            ),
          ),
          const Icon(Icons.chevron_right, color: _kTextSec, size: 18),
        ]),
      ),
    );
  }
}

class _LessonTile extends StatelessWidget {
  final Lesson lesson;
  final bool locked;
  final VoidCallback onTap;

  const _LessonTile({
    required this.lesson,
    required this.locked,
    required this.onTap,
  });

  IconData get _icon {
    if (locked) return Icons.lock_outline;
    if (lesson.completed) return Icons.check_circle;
    switch (lesson.type) {
      case LessonType.audio:
        return Icons.play_circle_outline;
      case LessonType.video:
        return Icons.smart_display_outlined;
      case LessonType.text:
        return Icons.article_outlined;
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
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        decoration: BoxDecoration(
          color: _kSurface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
        ),
        child: Row(children: [
          Icon(_icon,
              size: 20,
              color: lesson.completed && !locked ? _kAccent : _kTextSec),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(lesson.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: lesson.isPlayable ? Colors.white : _kTextSec)),
                const SizedBox(height: 2),
                Text(_subtitle,
                    style: const TextStyle(fontSize: 11, color: _kTextSec)),
              ],
            ),
          ),
        ]),
      ),
    );
  }
}
