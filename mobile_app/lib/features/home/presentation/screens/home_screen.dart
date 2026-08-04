import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_theme.dart';
import '../../../../app/widgets/botanical.dart';
import '../../../access/application/access_providers.dart';
import '../../../access/data/popup_seen_store.dart';
import '../../../access/domain/access_state.dart';
import '../../../access/domain/entities/app_popup.dart';
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
import '../../../live/application/live_providers.dart';
import '../../../live/presentation/widgets/live_session_card.dart';
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

    final popup = access.todaysPopup;
    if (access.hasAccess && popup != null && !_popupShown) {
      // Latched before the async gap, not after: build can run again
      // before the storage read returns, and two builds both passing the
      // check would open the dialog twice.
      _popupShown = true;
      final registered = access.registeredPopupIds.contains(popup.id);
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _showPopup(popup, registered: registered),
      );
    }
  }

  Future<void> _showPopup(AppPopup popup, {required bool registered}) async {
    final today = popup.todayKey;
    if (await PopupSeenStore.wasSeen(popup.id, today)) return;
    if (!mounted) return;

    // Recorded before the dialog closes rather than after, so dismissing
    // it by swiping the app away still counts as seen. The alternative
    // shows it again on the next launch to somebody who has already read
    // it and decided they were done.
    await PopupSeenStore.markSeen(popup.id, today);
    if (!mounted) return;
    await NextEventPopup.show(context, popup, alreadyRegistered: registered);
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
          ref.invalidate(upcomingSessionsProvider);
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
            const SizedBox(height: 12),

            // Directly under search, and worded as a question rather than
            // labelled "Chat". Nobody opens a meditation app looking for
            // a chatbot; they open it not knowing how long to sit for.
            _GuideBar(onTap: () => context.push('/chat')),
            const SizedBox(height: 22),

            const _ContinueCard(),

            // Above everything else, and only when there is one. A live
            // session is the single thing in this app that expires: it is
            // the reason a notification was sent, and the card that
            // notification is telling people to tap. Leaving it three taps
            // deep behind a "Watch on YouTube" heading meant the reminder
            // arrived and the thing it referred to was nowhere in sight.
            const _LiveSessionSection(),

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
              title: 'Watch',
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

// ── Live sessions ────────────────────────────────────────────────────

/// Upcoming live sessions, or nothing at all.
///
/// Renders nothing while loading and nothing on error, rather than a
/// spinner or a message: this section is absent most of the time, and a
/// placeholder for something that usually doesn't exist is worse than
/// silence.
class _LiveSessionSection extends ConsumerWidget {
  const _LiveSessionSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessions =
        ref.watch(upcomingSessionsProvider).asData?.value ?? const [];
    final live = sessions.where((s) => !s.isCancelled && !s.isOver).toList();
    if (live.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionTitle(
          title: live.length == 1 ? 'Live session' : 'Live sessions',
          action: 'See all',
          onAction: () => context.push('/watch'),
        ),
        const SizedBox(height: 12),
        // Only the next one here. The rest are a tap away on Watch —
        // Home is a starting point, not a schedule.
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: LiveSessionCard(session: live.first),
        ),
        const SizedBox(height: 24),
      ],
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
            // The sprig is painted behind the avatar and allowed to run
            // off the right edge, which is what makes the leaves read as
            // part of the page rather than as a badge on the avatar.
            SizedBox(
              width: 62,
              height: 62,
              child: Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.center,
                children: [
                  const Positioned(
                    right: -34,
                    top: 4,
                    child: LeafSprig(size: 108, angle: -0.4, opacity: 0.55),
                  ),
                  const Positioned(
                    left: -26,
                    bottom: -6,
                    child: LeafSprig(
                      size: 78,
                      angle: 2.7,
                      opacity: 0.45,
                      flip: true,
                    ),
                  ),
                  GestureDetector(
                    onTap: onProfile,
                    child: Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        gradient: AppTheme.sageGradient,
                        shape: BoxShape.circle,
                        boxShadow: AppTheme.rowShadow,
                      ),
                      child: Center(
                        child: Text(
                          username.characters.first.toUpperCase(),
                          style: const TextStyle(
                            fontFamily: AppTheme.text,
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
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

class _GuideBar extends StatelessWidget {
  final VoidCallback onTap;
  const _GuideBar({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: AppTheme.claySurface(
            color: AppTheme.sageSoft,
            radius: AppTheme.radiusRow,
            small: true,
          ),
          child: Row(children: [
            Container(
              width: 34,
              height: 34,
              decoration: const BoxDecoration(
                gradient: AppTheme.sageGradient,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.self_improvement_rounded,
                  size: 19, color: Colors.white),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Ask the guide',
                    style: TextStyle(
                      fontFamily: AppTheme.text,
                      fontSize: 14.5,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'How to meditate, what to play next',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: AppTheme.text,
                      fontSize: 12,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded,
                size: 20, color: AppTheme.sageDark),
          ]),
        ),
      ),
    );
  }
}

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
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 17),
          decoration: BoxDecoration(
            gradient: AppTheme.clayFill(AppTheme.surface),
            borderRadius: BorderRadius.circular(AppTheme.radiusPill),
            boxShadow: AppTheme.cardShadow,
          ),
          child: const Row(children: [
            Icon(Icons.search_rounded, size: 23, color: AppTheme.textSecondary),
            SizedBox(width: 12),
            Text(
              'Search for anything',
              style: TextStyle(
                fontFamily: AppTheme.text,
                fontSize: 15.5,
                color: AppTheme.textSecondary,
              ),
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
              fontFamily: AppTheme.display,
              fontSize: 21,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
            ),
          ),
        ),
        if (action != null)
          TextButton(
            onPressed: onAction,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  action!,
                  style: const TextStyle(
                    fontFamily: AppTheme.text,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.sageDark,
                  ),
                ),
                const SizedBox(width: 2),
                const Icon(Icons.chevron_right_rounded,
                    size: 18, color: AppTheme.sageDark),
              ],
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
      orElse: () => const SizedBox(height: 104),
      data: (categories) {
        if (categories.isEmpty) return const SizedBox.shrink();
        return SizedBox(
          height: 104,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: categories.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (_, i) {
              final c = categories[i];
              return GestureDetector(
                onTap: () => onTap(c),
                child: SizedBox(
                  width: 74,
                  child: Column(
                    children: [
                      Container(
                        width: 68,
                        height: 68,
                        decoration: AppTheme.claySurface(
                          color: AppTheme.surfaceCream,
                          radius: 22,
                          small: true,
                        ),
                        child: Icon(
                          _categoryIcon(c.name, c.slug),
                          size: 30,
                          color: AppTheme.sageDark,
                        ),
                      ),
                      const SizedBox(height: 7),
                      Text(
                        c.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontFamily: AppTheme.text,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
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

/// Picks a glyph for a category from its name.
///
/// A lookup here rather than a column on the table: categories are
/// created by an admin typing a name, and asking them to also choose a
/// Material icon id would be a worse job than guessing well and falling
/// back to the lotus. Matched on substrings so "Guided Meditation" and
/// "Meditations" both land on the same leaf.
IconData _categoryIcon(String name, String slug) {
  final key = '$name $slug'.toLowerCase();
  if (key.contains('medit')) return Icons.spa_outlined;
  if (key.contains('spirit') || key.contains('soul')) {
    return Icons.self_improvement_rounded;
  }
  if (key.contains('course') || key.contains('learn')) {
    return Icons.menu_book_outlined;
  }
  if (key.contains('mantra') || key.contains('chant') ||
      key.contains('music') || key.contains('bhajan')) {
    return Icons.music_note_outlined;
  }
  if (key.contains('well') || key.contains('health') ||
      key.contains('heal')) {
    return Icons.favorite_border_rounded;
  }
  if (key.contains('sleep') || key.contains('night')) {
    return Icons.nightlight_outlined;
  }
  if (key.contains('breath') || key.contains('pranayam')) {
    return Icons.air_rounded;
  }
  if (key.contains('yoga')) return Icons.accessibility_new_rounded;
  if (key.contains('talk') || key.contains('podcast') ||
      key.contains('satsang')) {
    return Icons.record_voice_over_outlined;
  }
  return Icons.filter_vintage_outlined;
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

        // Near-full-width cards, so the first one reads as the hero the
        // design leads with while the rest stay one swipe away. A single
        // hero with the others dropped would have made every course
        // after the first unreachable from Home.
        final width = MediaQuery.of(context).size.width - 40;

        return SizedBox(
          height: 260,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: courses.length,
            separatorBuilder: (_, __) => const SizedBox(width: 14),
            itemBuilder: (_, i) {
              return _CourseMiniCard(course: courses[i], width: width);
            },
          ),
        );
      },
    );
  }
}

class _CourseMiniCard extends StatelessWidget {
  final CourseSummary course;
  final double width;

  const _CourseMiniCard({required this.course, required this.width});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push('/course/${course.id}', extra: course.title),
      child: Container(
        width: width,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppTheme.radiusCard),
          boxShadow: AppTheme.cardShadow,
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (course.coverImageUrl != null &&
                course.coverImageUrl!.isNotEmpty)
              Image.network(
                course.coverImageUrl!,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const _MiniCover(),
              )
            else
              const _MiniCover(),

            // A scrim from the left rather than the bottom. Course covers
            // in this library put the teacher on the right, and a bottom
            // scrim darkens their face while leaving the title on a busy
            // background — this does the opposite of both.
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [Color(0xE60F2019), Color(0x000F2019)],
                  stops: [0.05, 0.85],
                ),
              ),
            ),

            Positioned(
              top: 14,
              right: 14,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.94),
                  borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (!course.owned && !course.isFree) ...[
                      const Icon(Icons.lock_rounded,
                          size: 13, color: AppTheme.clay),
                      const SizedBox(width: 5),
                    ],
                    Text(
                      course.owned ? 'Enrolled' : course.priceLabel,
                      style: TextStyle(
                        fontFamily: AppTheme.text,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: course.owned || course.isFree
                            ? AppTheme.sageDark
                            : AppTheme.clay,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    course.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: AppTheme.display,
                      fontSize: 27,
                      height: 1.15,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  const Spacer(),
                  if (course.isStarted) ...[
                    SizedBox(
                      width: 170,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: course.progressFraction,
                          backgroundColor: Colors.white24,
                          valueColor:
                              const AlwaysStoppedAnimation(AppTheme.sandSoft),
                          minHeight: 5,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${course.completedLessonCount} of '
                      '${course.lessonCount} done',
                      style: const TextStyle(
                        fontFamily: AppTheme.text,
                        fontSize: 12.5,
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                  // Styled as a button, but the whole card is still the
                  // one tap target — the card was tappable before and
                  // adding a second gesture here would give the same
                  // destination two overlapping hit areas.
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.94),
                      borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          course.isStarted ? 'Continue' : 'Start Course',
                          style: const TextStyle(
                            fontFamily: AppTheme.text,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(Icons.arrow_forward_rounded,
                            size: 16, color: AppTheme.textPrimary),
                      ],
                    ),
                  ),
                ],
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
      orElse: () => const SizedBox(height: 268),
      data: (audios) {
        if (audios.isEmpty) return const SizedBox.shrink();

        return SizedBox(
          // Fixed rather than intrinsic: every card is the same height so
          // the duration pills line up across the row, which is what
          // stops a two-line title from shunting one card's footer down.
          height: 268,
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
                child: Container(
                  width: 208,
                  decoration: AppTheme.claySurface(),
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // The cover is edge-to-edge across the card's top,
                      // with only its own corners rounded — a floated
                      // thumbnail inside a card reads as two cards.
                      SizedBox(
                        height: 148,
                        width: double.infinity,
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
                          const Positioned(
                            right: 10,
                            bottom: 10,
                            child: _PlayBubble(),
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
                                audio.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontFamily: AppTheme.text,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.textPrimary,
                                ),
                              ),
                              if (audio.artist != null &&
                                  audio.artist!.trim().isNotEmpty) ...[
                                const SizedBox(height: 2),
                                Text(
                                  'by ${audio.artist!.trim()}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontFamily: AppTheme.text,
                                    fontSize: 13,
                                    color: AppTheme.textSecondary,
                                  ),
                                ),
                              ],
                              const Spacer(),
                              if (audio.durationSeconds != null)
                                _MetaPill(
                                  icon: Icons.schedule_rounded,
                                  label:
                                      '${(audio.durationSeconds! / 60).round()} Min',
                                ),
                            ],
                          ),
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

/// The white circle with a sage triangle, sitting over the cover art.
///
/// Decoration, not a second button: the whole card is already the tap
/// target, and a nested GestureDetector here would give the same action
/// two hit areas with different shapes.
class _PlayBubble extends StatelessWidget {
  const _PlayBubble();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: const Icon(Icons.play_arrow_rounded,
          size: 26, color: AppTheme.sageDark),
    );
  }
}

/// A small tinted pill for a piece of metadata — duration, lesson count.
class _MetaPill extends StatelessWidget {
  final IconData icon;
  final String label;

  const _MetaPill({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppTheme.sageSoft,
        borderRadius: BorderRadius.circular(AppTheme.radiusPill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: AppTheme.sageDark),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              fontFamily: AppTheme.text,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppTheme.sageDark,
            ),
          ),
        ],
      ),
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
