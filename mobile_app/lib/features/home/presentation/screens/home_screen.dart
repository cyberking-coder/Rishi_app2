import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_theme.dart';
import '../../../access/application/access_providers.dart';
import '../../../access/domain/access_state.dart';
import '../../../access/presentation/next_event_popup.dart';
import '../../../audio/application/audio_providers.dart';
import '../../../audio/domain/entities/audio_track.dart';
import '../../../downloads/application/download_providers.dart';
import '../../../profile/application/profile_providers.dart';
import '../../application/home_providers.dart';
import '../../domain/entities/audio_summary.dart';
import '../../domain/entities/category_summary.dart';
import '../../domain/entities/continue_listening_item.dart';
import '../../../lms/application/lms_providers.dart';
import '../../../lms/domain/entities/course_summary.dart';
import '../../../watch/application/watch_providers.dart';
import '../../../watch/presentation/widgets/youtube_card.dart';
import '../widgets/premium_lock.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with WidgetsBindingObserver {
  bool _popupShown = false;
  bool _purged = false;
  bool _starting = false;

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
    // Re-check access when the app comes back to the foreground - this is
    // what makes a purchase feel like it unlocks immediately when the user
    // returns from the external checkout browser, without needing to
    // force-quit or manually re-navigate.
    if (state == AppLifecycleState.resumed) {
      ref.invalidate(accessStateProvider);
    }
  }

  void _onAccess(AccessState access) {
    if (access.isExpired && !_purged) {
      _purged = true;
      ref.read(downloadRepositoryProvider).purgeAll();
      return;
    }
    if (access.hasAccess && access.shouldShowPopup && !_popupShown) {
      _popupShown = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) NextEventPopup.show(context, access);
      });
    }
  }

  Future<void> _playAudio(AudioSummary audio) async {
    if (_starting) return; // guard against a double-tap opening twice
    final access = ref.read(accessStateProvider).valueOrNull;
    if (audio.isPremium && access?.hasAccess != true) {
      showPremiumLockedMessage(context, ref);
      return;
    }
    _starting = true;
    try {
      await ref.read(audioHandlerProvider).playSingleTrack(AudioTrack(
            id: audio.id,
            title: audio.title,
            artist: audio.artist,
            coverArtUrl: audio.coverArtUrl,
            durationSeconds: audio.durationSeconds,
          ));
      if (mounted) context.push('/now-playing');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      _starting = false;
    }
  }

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return "Let's start the day gently";
    if (h < 17) return 'A pause for the afternoon';
    return 'Wind down for the evening';
  }

  @override
  Widget build(BuildContext context) {
    final access = ref.watch(accessStateProvider).valueOrNull;
    if (access != null) _onAccess(access);

    // Only a real (possibly unlimited) retreat window shows a countdown —
    // a free-tier user was never granted one, so there's nothing to count
    // down to zero forever.
    final daysLeft = access?.tier == UserTier.retreat ? access?.daysLeft : null;

    final profile = ref.watch(userProfileProvider).valueOrNull;
    final rawName = profile?.displayName?.trim().isNotEmpty == true
        ? profile!.displayName!.trim()
        : (profile?.email.split('@').first ?? 'there');
    final username = rawName.isEmpty ? 'there' : rawName;

    return SafeArea(
      bottom: false,
      child: RefreshIndicator(
        color: AppTheme.sage,
        onRefresh: () async {
          ref.invalidate(featuredAudiosProvider);
          ref.invalidate(categoriesProvider);
          ref.invalidate(coursesProvider);
          ref.invalidate(continueListeningProvider);
          ref.invalidate(youtubeVideosProvider);
        },
        child: ListView(
          padding: const EdgeInsets.only(bottom: 28),
          children: [
            _Header(
              username: username,
              greeting: _greeting(),
              daysLeft: daysLeft,
              onProfile: () => context.go('/profile'),
            ),
            const SizedBox(height: 16),

            _SearchBar(onTap: () => context.push('/search')),
            const SizedBox(height: 22),

            const _ContinueCard(),

            _SectionTitle(
              title: 'Categories',
              action: 'See all',
              onAction: () => context.push('/search'),
            ),
            const SizedBox(height: 10),
            _CategoriesRow(
              onTap: (c) => context.push('/category/${c.id}', extra: c.name),
            ),
            const SizedBox(height: 24),

            // Audio leads: it's the app's core content and was previously
            // below the courses row, far enough down that it went unseen.
            _SectionTitle(
              title: 'Featured for you',
              action: 'See all',
              onAction: () => context.push('/search'),
            ),
            const SizedBox(height: 12),
            _FeaturedRow(onPlay: _playAudio),
            const SizedBox(height: 24),

            _SectionTitle(
              title: 'Courses',
              action: 'See all',
              onAction: () => context.go('/courses'),
            ),
            const SizedBox(height: 12),
            const _CoursesRow(),
            const SizedBox(height: 24),

            _SectionTitle(
              title: 'Watch on YouTube',
              action: 'See all',
              onAction: () => context.push('/watch'),
            ),
            const SizedBox(height: 12),
            const _YoutubeRow(),
          ],
        ),
      ),
    );
  }
}

// ── Header ───────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  final String username;
  final String greeting;
  final int? daysLeft;
  final VoidCallback onProfile;

  const _Header({
    required this.username,
    required this.greeting,
    required this.onProfile,
    this.daysLeft,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Eyebrow above, display line below — the design puts
                  // the time of day in small caps and the person's name
                  // in the serif, rather than the other way round: the
                  // greeting is context, the name is the moment.
                  Text(
                    greeting.toUpperCase(),
                    style: AppTheme.label,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Hi, $username',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTheme.displayLarge,
                  ),
                ],
              ),
            ),
            GestureDetector(
              onTap: onProfile,
              child: Container(
                width: 44,
                height: 44,
                decoration: const BoxDecoration(
                  gradient: AppTheme.sageGradient,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    username.characters.first.toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
          ]),
          if (daysLeft != null && daysLeft! <= 7) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              decoration: BoxDecoration(
                color: AppTheme.sandSoft,
                borderRadius: BorderRadius.circular(AppTheme.radiusRow),
              ),
              child: Row(children: [
                const Icon(Icons.schedule_rounded,
                    size: 15, color: AppTheme.clay),
                const SizedBox(width: 8),
                Text(
                  daysLeft! <= 0
                      ? 'Your access ends today'
                      : daysLeft == 1
                          ? '1 day of access left'
                          : '$daysLeft days of access left',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.clay,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ]),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Search ───────────────────────────────────────────────────────────

class _SearchBar extends StatelessWidget {
  final VoidCallback onTap;
  const _SearchBar({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            gradient: AppTheme.clayFill(),
            borderRadius: BorderRadius.circular(AppTheme.radiusPill),
            boxShadow: AppTheme.cardShadow,
          ),
          child: const Row(children: [
            Icon(Icons.search_rounded, size: 20, color: AppTheme.textSecondary),
            SizedBox(width: 10),
            Text(
              'Search for anything',
              style: TextStyle(fontSize: 14, color: AppTheme.textSecondary),
            ),
          ]),
        ),
      ),
    );
  }
}

// ── Section heading ──────────────────────────────────────────────────

class _SectionTitle extends StatelessWidget {
  final String title;
  final String? action;
  final VoidCallback? onAction;

  const _SectionTitle({required this.title, this.action, this.onAction});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 12, 0),
      child: Row(children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: AppTheme.textPrimary,
            ),
          ),
        ),
        if (action != null)
          TextButton(
            onPressed: onAction,
            child: Text(
              action!,
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: AppTheme.sage,
              ),
            ),
          ),
      ]),
    );
  }
}

// ── Continue listening ───────────────────────────────────────────────

class _ContinueCard extends ConsumerWidget {
  const _ContinueCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(continueListeningProvider);

    return async.maybeWhen(
      orElse: () => const SizedBox.shrink(),
      data: (items) {
        if (items.isEmpty) return const SizedBox.shrink();
        final item = items.first;

        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          child: GestureDetector(
            onTap: () => _resume(context, ref, item),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                gradient: AppTheme.sageGradient,
                borderRadius: BorderRadius.circular(AppTheme.radiusCard),
                boxShadow: AppTheme.cardShadow,
              ),
              child: Row(children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: SizedBox(
                    width: 54,
                    height: 54,
                    child: item.coverArtUrl != null
                        ? Image.network(
                            item.coverArtUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) =>
                                const ColoredBox(color: Colors.white24),
                          )
                        : const ColoredBox(
                            color: Colors.white24,
                            child: Icon(Icons.music_note_rounded,
                                color: Colors.white70),
                          ),
                  ),
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'CONTINUE LISTENING',
                        style: TextStyle(
                          fontSize: 9.5,
                          letterSpacing: 0.8,
                          fontWeight: FontWeight.w800,
                          color: Colors.white70,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: item.progressFraction,
                          backgroundColor: Colors.white24,
                          valueColor:
                              const AlwaysStoppedAnimation(Colors.white),
                          minHeight: 4,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  width: 40,
                  height: 40,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.play_arrow_rounded,
                      color: AppTheme.sage, size: 24),
                ),
              ]),
            ),
          ),
        );
      },
    );
  }

  Future<void> _resume(
    BuildContext context,
    WidgetRef ref,
    ContinueListeningItem item,
  ) async {
    try {
      await ref.read(audioHandlerProvider).playSingleTrack(
            AudioTrack(
              id: item.audioId,
              title: item.title,
              artist: item.teacher,
              coverArtUrl: item.coverArtUrl,
              durationSeconds: item.durationSeconds,
            ),
            // Continue Listening resumes where the user left off.
            resumeAt: Duration(seconds: item.progressSeconds),
          );
      if (context.mounted) context.push('/now-playing');
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }
}

// ── Categories ───────────────────────────────────────────────────────

class _CategoriesRow extends ConsumerWidget {
  final void Function(CategorySummary) onTap;
  const _CategoriesRow({required this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(categoriesProvider);

    return async.maybeWhen(
      orElse: () => const SizedBox(height: 40),
      data: (categories) {
        if (categories.isEmpty) return const SizedBox.shrink();
        return SizedBox(
          height: 40,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: categories.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (_, i) {
              final c = categories[i];
              return GestureDetector(
                onTap: () => onTap(c),
                child: Container(
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    gradient: AppTheme.clayFill(),
                    borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                    boxShadow: AppTheme.cardShadow,
                  ),
                  child: Text(
                    c.name,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

// ── Courses ──────────────────────────────────────────────────────────

class _CoursesRow extends ConsumerWidget {
  const _CoursesRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(coursesProvider);

    return async.maybeWhen(
      orElse: () => const SizedBox(height: 190),
      data: (courses) {
        if (courses.isEmpty) {
          return const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: _EmptyHint(
              icon: Icons.school_outlined,
              text: 'Courses will appear here once they are published.',
            ),
          );
        }

        return SizedBox(
          height: 196,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: courses.length,
            separatorBuilder: (_, __) => const SizedBox(width: 14),
            itemBuilder: (_, i) {
              return _CourseMiniCard(course: courses[i]);
            },
          ),
        );
      },
    );
  }
}

class _CourseMiniCard extends StatelessWidget {
  final CourseSummary course;

  const _CourseMiniCard({required this.course});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push('/course/${course.id}', extra: course.title),
      child: Container(
        width: 214,
        decoration: BoxDecoration(
          gradient: AppTheme.clayFill(),
          borderRadius: BorderRadius.circular(AppTheme.radiusCard),
          boxShadow: AppTheme.cardShadow,
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 104,
              width: double.infinity,
              child: Stack(fit: StackFit.expand, children: [
                if (course.coverImageUrl != null &&
                    course.coverImageUrl!.isNotEmpty)
                  Image.network(
                    course.coverImageUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const _MiniCover(),
                  )
                else
                  const _MiniCover(),
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.92),
                      borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                    ),
                    child: Text(
                      course.owned ? 'Enrolled' : course.priceLabel,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: course.owned || course.isFree
                            ? AppTheme.sage
                            : AppTheme.clay,
                      ),
                    ),
                  ),
                ),
              ]),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      course.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        height: 1.3,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const Spacer(),
                    if (course.isStarted) ...[
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: course.progressFraction,
                          backgroundColor: AppTheme.sageSoft,
                          valueColor:
                              const AlwaysStoppedAnimation(AppTheme.sage),
                          minHeight: 4,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${course.completedLessonCount} of '
                        '${course.lessonCount} done',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppTheme.sage,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ] else
                      Text(
                        '${course.lessonCount} '
                        '${course.lessonCount == 1 ? "lesson" : "lessons"}',
                        style: const TextStyle(
                          fontSize: 11.5,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniCover extends StatelessWidget {
  const _MiniCover();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(gradient: AppTheme.sageGradient),
      child: const Center(
        child: Icon(Icons.self_improvement_rounded,
            color: Colors.white38, size: 32),
      ),
    );
  }
}

// ── Featured audio ───────────────────────────────────────────────────

class _FeaturedRow extends ConsumerWidget {
  final void Function(AudioSummary) onPlay;
  const _FeaturedRow({required this.onPlay});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(featuredAudiosProvider);
    final access = ref.watch(accessStateProvider).valueOrNull;

    return async.maybeWhen(
      orElse: () => const SizedBox(height: 168),
      data: (audios) {
        if (audios.isEmpty) return const SizedBox.shrink();

        return SizedBox(
          height: 168,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: audios.length,
            separatorBuilder: (_, __) => const SizedBox(width: 14),
            itemBuilder: (_, i) {
              final audio = audios[i];
              final locked = audio.isPremium && access?.hasAccess != true;

              return GestureDetector(
                onTap: () => onPlay(audio),
                child: SizedBox(
                  width: 128,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        height: 118,
                        width: 128,
                        decoration: BoxDecoration(
                          borderRadius:
                              BorderRadius.circular(AppTheme.radiusCard),
                          boxShadow: AppTheme.cardShadow,
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: Stack(fit: StackFit.expand, children: [
                          if (audio.coverArtUrl != null &&
                              audio.coverArtUrl!.isNotEmpty)
                            Image.network(
                              audio.coverArtUrl!,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => const _MiniCover(),
                            )
                          else
                            const _MiniCover(),
                          if (locked) const PremiumLockBadge(),
                        ]),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        audio.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          height: 1.3,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

// ── Shared ───────────────────────────────────────────────────────────

class _EmptyHint extends StatelessWidget {
  final IconData icon;
  final String text;

  const _EmptyHint({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      decoration: BoxDecoration(
        gradient: AppTheme.clayFill(),
        borderRadius: BorderRadius.circular(AppTheme.radiusCard),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Row(children: [
        Icon(icon, size: 19, color: AppTheme.textSecondary),
        const SizedBox(width: 11),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 12.5,
              color: AppTheme.textSecondary,
              height: 1.4,
            ),
          ),
        ),
      ]),
    );
  }
}


// ── Watch on YouTube ─────────────────────────────────────────────────

class _YoutubeRow extends ConsumerWidget {
  const _YoutubeRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(youtubeVideosProvider);

    return async.maybeWhen(
      orElse: () => const SizedBox(height: 150),
      data: (videos) {
        if (videos.isEmpty) return const SizedBox.shrink();

        return SizedBox(
          height: 172,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: videos.length,
            separatorBuilder: (_, __) => const SizedBox(width: 14),
            itemBuilder: (_, i) {
              final video = videos[i];
              return GestureDetector(
                onTap: () => openYoutube(context, video),
                child: SizedBox(
                  width: 226,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      YoutubeThumbnail(video: video),
                      const SizedBox(height: 8),
                      Text(
                        video.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          height: 1.3,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}
