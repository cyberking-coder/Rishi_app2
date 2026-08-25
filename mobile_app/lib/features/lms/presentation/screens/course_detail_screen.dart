import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../app/theme/app_theme.dart';
import '../../../../app/widgets/remote_image.dart';
import '../../../../core/config/purchase_config.dart';
import '../../../audio/application/audio_providers.dart';
import '../../../audio/domain/entities/audio_track.dart';
import '../../application/lms_providers.dart';
import '../../domain/entities/lesson.dart';
import '../widgets/course_purchase_sheet.dart';

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

class _CourseDetailScreenState extends ConsumerState<CourseDetailScreen>
    with WidgetsBindingObserver {
  bool _starting = false;

  /// The course being viewed, once loaded — needed to price the purchase
  /// sheet from anywhere in this screen.
  CourseSummaryRef? _course;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Fallback for when the deep-link return from checkout doesn't fire
    // (browser/OS didn't follow the link, or the user manually switched
    // back instead of tapping "Return to app") — re-check ownership
    // whenever this screen comes back to the foreground rather than
    // leaving it stuck showing locked after a completed payment.
    if (state == AppLifecycleState.resumed) {
      ref.invalidate(courseDetailProvider(widget.courseId));
      ref.invalidate(coursesProvider);
    }
  }

  Future<void> _promptPurchase() async {
    final course = _course;
    if (course == null) return;
    await showCoursePurchaseSheet(
      context,
      ref,
      courseId: course.id,
      courseTitle: course.title,
      priceLabel: course.priceLabel,
    );
    // Coming back from checkout, re-read ownership so a completed
    // purchase unlocks without a manual refresh.
    ref.invalidate(courseDetailProvider(widget.courseId));
    ref.invalidate(coursesProvider);
  }

  Future<void> _openLesson(Lesson lesson, bool locked) async {
    if (locked) {
      await _promptPurchase();
      return;
    }

    if (!lesson.isPlayable) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("This $kPartWord's content isn't available right now."),
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
                    'Could not load this.\n$e',
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
          _course = detail.course;
          final locked = detail.course.isLocked;
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
                  onBack: () => _leaveCourse(context),
                ),
              ),

              // Sits below the hero with clear air between them. An
              // earlier version pulled this up to overlap the cover, but
              // slivers paint first-on-top, so the hero covered the card
              // and clipped the title.
              const SliverToBoxAdapter(child: SizedBox(height: 16)),
              SliverToBoxAdapter(
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
                      priceLabel: detail.course.priceLabel,
                      onPrimary: () {
                        if (locked) {
                          _promptPurchase();
                        } else if (next != null) {
                          _openLesson(next, false);
                        }
                      },
                    ),
                  ),
              ),

              SliverToBoxAdapter(
                child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 10),
                    child: Text(
                      // Missed in the first pass: the tab, the counts and
                      // the buttons all said episode while the list they
                      // sit above still announced itself as Lessons.
                      kEducationFramingEnabled ? 'LESSONS' : 'EPISODES',
                      style: AppTheme.label,
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
                    child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 10, 20, 8),
                        child: Text(
                          module.title.toUpperCase(),
                          style: AppTheme.label.copyWith(fontSize: 11.5),
                        ),
                      ),
                  ),
                SliverList.separated(
                  itemCount: module.lessons.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (_, i) {
                    final lesson = module.lessons[i];
                    lessonNumber++;
                    return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: _LessonTile(
                          number: lessonNumber,
                          lesson: lesson,
                          locked: locked,
                          onTap: () => _openLesson(lesson, locked),
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
        RemoteImage(
          url: coverUrl,
          fallback: const _HeroFallback(),
        ),

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
  final String priceLabel;
  final String? nextLessonTitle;
  final VoidCallback onPrimary;

  const _MetaCard({
    required this.title,
    required this.lessonCount,
    required this.completed,
    required this.progress,
    required this.locked,
    required this.priceLabel,
    required this.onPrimary,
    this.description,
    this.nextLessonTitle,
  });

  @override
  Widget build(BuildContext context) {
    final started = completed > 0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.glassSurface(radius: AppTheme.radiusCard),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontFamily: AppTheme.text,
                    fontSize: 20,
                    height: 1.2,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.4,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$lessonCount ${lessonCount == 1 ? kPartWord : "${kPartWord}s"}',
                  style: const TextStyle(
                    fontFamily: AppTheme.text,
                    fontSize: 13,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          if (locked) ...[
            const SizedBox(width: 12),
            Container(
              height: 24,
              padding: const EdgeInsets.symmetric(horizontal: 9),
              decoration: BoxDecoration(
                color: AppTheme.well,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.lock_rounded,
                    size: 13, color: AppTheme.textSecondary),
                const SizedBox(width: 4),
                Text(
                  // The lock stays on iOS, the price does not: locked
                  // content may be shown, priced content may not.
                  kPurchaseUiEnabled ? priceLabel : 'Locked',
                  style: const TextStyle(
                    fontFamily: AppTheme.text,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ]),
            ),
          ],
        ]),

        if (description != null && description!.trim().isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(
            description!,
            style: const TextStyle(
              fontFamily: AppTheme.text,
              fontSize: 15,
              color: Color(0xFF544A6E),
              height: 1.5,
            ),
          ),
        ],

        if (started && !locked) ...[
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: AppTheme.well,
              valueColor: const AlwaysStoppedAnimation(AppTheme.sage),
              minHeight: 3,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                completed >= lessonCount ? 'Completed' : 'In progress',
                style: const TextStyle(
                  fontFamily: AppTheme.text,
                  fontSize: 13,
                  color: AppTheme.textSecondary,
                ),
              ),
              Text(
                '${(progress * 100).round()}%',
                style: const TextStyle(
                  fontFamily: AppTheme.text,
                  fontSize: 13,
                  color: AppTheme.textSecondary,
                ),
              ),
            ],
          ),
        ],

        if (locked || nextLessonTitle != null) ...[
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: onPrimary,
              child: Text(
                locked
                    ? kPurchaseUiEnabled
                        ? 'Get access · $priceLabel'
                        : 'Why is this locked?'
                    : started
                        ? (kEducationFramingEnabled
                            ? 'Continue learning'
                            : 'Continue watching')
                        : (kEducationFramingEnabled
                            ? 'Start course'
                            : 'Start watching'),
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

  /// "Not started · 14 min" — state first, then the fact about it.
  ///
  /// The state used to live only in the leading badge, as one of three
  /// shades. Saying it in words costs nothing and means the row reads
  /// without anyone having to learn what the tint means.
  String get _subtitle {
    if (!lesson.isPlayable) return 'Unavailable';

    final state = locked
        ? 'Locked'
        : lesson.completed
            ? 'Completed'
            : 'Not started';

    switch (lesson.type) {
      case LessonType.audio:
        final secs = lesson.audioDurationSeconds;
        if (secs == null) return '$state · Audio';
        return '$state · ${(secs / 60).ceil()} min';
      case LessonType.video:
        return '$state · Video';
      case LessonType.text:
        return '$state · Reading';
    }
  }

  @override
  Widget build(BuildContext context) {
    final done = lesson.completed && !locked;

    return Container(
      decoration: AppTheme.glassSurface(),
      clipBehavior: Clip.antiAlias,
      child: Column(children: [
        InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(children: [
              // Leading badge shows state first (locked / done) and
              // falls back to the media type — the state is what
              // decides whether tapping does anything.
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: done ? AppTheme.sage : AppTheme.sageSoft,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(
                  locked
                      ? Icons.lock_rounded
                      : done
                          ? Icons.check_rounded
                          : _typeIcon,
                  size: 22,
                  color: done ? Colors.white : AppTheme.sageDark,
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
                        fontFamily: AppTheme.text,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        letterSpacing: -0.16,
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
                        fontFamily: AppTheme.text,
                        fontSize: 13,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right_rounded,
                  size: 18, color: Color(0xFF9890AC)),
            ]),
          ),
        ),

        // Attachments sit under the lesson they belong to, visually
        // subordinate — they support the lesson rather than being one.
        if (!locked && lesson.resources.isNotEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final resource in lesson.resources)
                  _ResourceRow(resource: resource),
              ],
            ),
          ),
      ]),
    );
  }
}

class _ResourceRow extends StatefulWidget {
  final LessonResource resource;

  const _ResourceRow({required this.resource});

  @override
  State<_ResourceRow> createState() => _ResourceRowState();
}

class _ResourceRowState extends State<_ResourceRow> {
  bool _opening = false;

  LessonResource get resource => widget.resource;

  IconData get _icon {
    switch (resource.type) {
      case ResourceType.pdf:
        return Icons.picture_as_pdf_rounded;
      case ResourceType.image:
        return Icons.image_rounded;
      case ResourceType.file:
        return Icons.download_rounded;
      case ResourceType.link:
        return Icons.link_rounded;
    }
  }

  /// Links go to the browser; files are downloaded and handed to the
  /// system "open with" chooser.
  ///
  /// Sending a file URL to the browser instead just renders it inline in
  /// whatever viewer the browser happens to have — a PDF came out looking
  /// like a flat image with no page controls, and the user never got to
  /// pick their own PDF app. Downloading first means the OS offers the
  /// real chooser and the file can be kept.
  Future<void> _open() async {
    if (_opening) return;

    final uri = Uri.tryParse(resource.url);
    if (uri == null) return;

    if (resource.type == ResourceType.link) {
      final opened =
          await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!opened && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open this link.')),
        );
      }
      return;
    }

    setState(() => _opening = true);
    try {
      final response = await http.get(uri);
      if (response.statusCode != 200) {
        throw Exception('Download failed (${response.statusCode})');
      }

      // Named from the resource title so the chooser and any app the
      // user picks show something meaningful, with the extension taken
      // from the URL so the OS can match handlers.
      final dir = await getTemporaryDirectory();
      final extension = _extensionFor(uri);
      final safeName =
          resource.title.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
      final file = File('${dir.path}/$safeName$extension');
      await file.writeAsBytes(response.bodyBytes);

      final result = await OpenFilex.open(file.path);
      if (result.type != ResultType.done && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              result.type == ResultType.noAppToOpen
                  ? 'No app on this device can open that file.'
                  : 'Could not open this file.',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  String _extensionFor(Uri uri) {
    final last = uri.pathSegments.isEmpty ? '' : uri.pathSegments.last;
    final dot = last.lastIndexOf('.');
    if (dot != -1 && dot < last.length - 1) return last.substring(dot);
    // Fall back to the declared type when the URL carries no extension —
    // without one the OS has nothing to match a handler against.
    switch (resource.type) {
      case ResourceType.pdf:
        return '.pdf';
      case ResourceType.image:
        return '.jpg';
      case ResourceType.file:
      case ResourceType.link:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: _open,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 4),
        child: Row(children: [
          Icon(_icon, size: 15, color: AppTheme.sage),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              resource.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppTheme.sage,
              ),
            ),
          ),
          if (_opening)
            const SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(
                strokeWidth: 1.5,
                color: AppTheme.sage,
              ),
            )
          else
            const Icon(Icons.open_in_new_rounded,
                size: 12, color: AppTheme.textSecondary),
        ]),
      ),
    );
  }
}

// ── Shared ───────────────────────────────────────────────────────────

/// Back out of the course, whatever route brought us here.
///
/// A plain pop() blanked the screen when there was nothing beneath: the
/// payment deep link lands with go(), which replaces the stack rather
/// than pushing onto it, so the course was the only route and popping it
/// left the navigator empty. Fall back to the course list, which is
/// where "back" means to go anyway.
void _leaveCourse(BuildContext context) {
  final navigator = Navigator.of(context);
  if (navigator.canPop()) {
    navigator.pop();
  } else {
    context.go('/courses');
  }
}

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
          onPressed: () => _leaveCourse(context),
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
