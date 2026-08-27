import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_theme.dart';
import '../../../../app/widgets/remote_image.dart';
import '../../../../core/config/purchase_config.dart';
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
    // Only for an account whose retreat window has actually run out —
    // NOT for anyone merely outside one. `isExpired` is true for every
    // ordinary free account, so purging on it deleted the downloads of
    // every free user as soon as they came back to this screen, which is
    // the whole of the "my downloads vanish" report.
    if (access.hasLapsed && !_purged) {
      _purged = true;
      // Loud on purpose. This deletes every offline file the account
      // holds, it is driven by one boolean derived from server data, and
      // when it fired wrongly it was completely silent — the downloads
      // were simply gone, with nothing anywhere to say why or by whose
      // decision. If this line is in the log, the purge is the cause.
      debugPrint(
        'HomeScreen: access has lapsed (expiresAt=${access.expiresAt}, '
        'role=${access.role}) — purging ALL offline downloads.',
      );
      ref.read(downloadRepositoryProvider).purgeAll();
      return;
    }

    final popup = access.todaysPopup;
    if (access.hasAccess && popup != null && !_popupShown) {
      // Latched before the async gap, not after: build can run again
      // before the storage read returns, and two builds both passing the
      // check would open the dialog twice.
      _popupShown = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _showPopup(popup));
    }
  }

  Future<void> _showPopup(AppPopup popup) async {
    final today = popup.todayKey;
    if (await PopupSeenStore.wasSeen(popup.id, today)) return;
    if (!mounted) return;

    // Recorded before the dialog closes rather than after, so dismissing
    // it by swiping the app away still counts as seen. The alternative
    // shows it again on the next launch to somebody who has already read
    // it and decided they were done.
    await PopupSeenStore.markSeen(popup.id, today);
    if (!mounted) return;
    await NextEventPopup.show(context, popup);
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

  /// First name only.
  ///
  /// The headline is 32px, and the room beside the avatar is about 300pt
  /// — roughly eighteen characters. "Hi, Priyanka Deshmukh" does not fit
  /// and would ellipsise into "Hi, Priyanka Deshm…", which is worse than
  /// either the full name or the first one. A display name is also
  /// frequently just the first name already, in which case this changes
  /// nothing.
  String _firstName(String full) {
    final first = full.trim().split(RegExp(r'\s+')).first;
    return first.isEmpty ? full.trim() : first;
  }

  /// "Sunday, 23 August" — the eyebrow above the greeting.
  ///
  /// Spelled out here rather than via intl's DateFormat: the app does not
  /// otherwise depend on intl, and one line of names is cheaper than a
  /// package plus locale initialisation for a single string.
  String _today() {
    const days = [
      'Monday', 'Tuesday', 'Wednesday', 'Thursday',
      'Friday', 'Saturday', 'Sunday',
    ];
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December',
    ];
    final now = DateTime.now();
    return '${days[now.weekday - 1]}, ${now.day} ${months[now.month - 1]}';
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
              eyebrow: _today(),
              displayName: _firstName(username),
              daysLeft: daysLeft,
              onProfile: () => context.go('/profile'),
            ),
            const SizedBox(height: 22),

            _SearchBar(onTap: () => context.push('/search')),
            const SizedBox(height: 12),

            // Directly under search, and worded as a question rather than
            // labelled "Chat". Nobody opens a meditation app looking for
            // a chatbot; they open it not knowing how long to sit for.
            _GuideBar(onTap: () => context.push('/chat')),
            const SizedBox(height: 22),

            const _ContinueCard(),


            _SectionTitle(
              title: 'Browse',
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
              title: 'Featured',
              action: 'See all',
              onAction: () => context.push('/search'),
            ),
            const SizedBox(height: 12),
            _FeaturedRow(onPlay: _playAudio),
            const SizedBox(height: 24),

            _SectionTitle(
              title: kEducationFramingEnabled ? 'Courses' : 'Videos',
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

// ── Header ───────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  /// The full name, used for the avatar's initial.
  final String username;
  final String eyebrow;

  /// What the greeting says after "Hi," — the first name.
  final String displayName;
  final int? daysLeft;
  final VoidCallback onProfile;

  const _Header({
    required this.username,
    required this.eyebrow,
    required this.displayName,
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
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // The date is the eyebrow, the person is the display
                    // line. This said "Good morning" for a while, which
                    // greeted nobody in particular and could go stale:
                    // it is computed when the screen builds, so an app
                    // left open from morning to evening kept insisting
                    // it was morning. A name is true whenever it is
                    // read.
                    Text(eyebrow.toUpperCase(), style: AppTheme.label),
                    const SizedBox(height: 2),
                    Text(
                      'Hi, $displayName',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTheme.displayLarge,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              // A soft lavender disc with a deep-violet initial, not a
              // saturated gradient chip. It sits beside a 32px heading
              // and has to stay quieter than it.
              GestureDetector(
                onTap: onProfile,
                child: Container(
                  width: 38,
                  height: 38,
                  decoration: const BoxDecoration(
                    color: AppTheme.sageSoft,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      username.characters.first.toUpperCase(),
                      style: const TextStyle(
                        fontFamily: AppTheme.text,
                        color: Color(0xFF4C1D95),
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
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
          padding: const EdgeInsets.all(12),
          decoration: AppTheme.glassSurface(),
          child: Row(children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: AppTheme.sageSoft,
                borderRadius: BorderRadius.circular(11),
              ),
              child: const Icon(Icons.self_improvement_rounded,
                  size: 19, color: AppTheme.sageDark),
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
        // A shallow well rather than a raised pill. Search is not a
        // feature of the page, it is a hole in it — and a lifted white
        // capsule directly under a 32px heading competed with it.
        child: Container(
          height: 38,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: AppTheme.well,
            borderRadius: BorderRadius.circular(11),
          ),
          child: const Row(children: [
            Icon(Icons.search_rounded, size: 18, color: AppTheme.textSecondary),
            SizedBox(width: 8),
            Text(
              'Search',
              style: TextStyle(
                fontFamily: AppTheme.text,
                fontSize: 15,
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
        Expanded(child: Text(title, style: AppTheme.headline)),
        if (action != null)
          TextButton(
            onPressed: onAction,
            child: Text(
              action!,
              style: const TextStyle(
                fontFamily: AppTheme.text,
                fontSize: 14.5,
                fontWeight: FontWeight.w500,
                color: AppTheme.sageDark,
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
            // Glass on the canvas, not a solid violet slab. The violet
            // is spent on the one thing that should be tapped — the play
            // button — instead of on the whole card, which is what made
            // the old one shout over every section below it.
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: AppTheme.glassSurface(),
              child: Row(children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(11),
                  child: SizedBox(
                    width: 52,
                    height: 52,
                    child: RemoteImage(
                      url: item.coverArtUrl,
                      fallback: const _ArtFallback(),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'CONTINUE',
                        style: TextStyle(
                          fontFamily: AppTheme.text,
                          fontSize: 11,
                          letterSpacing: 0.66,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.sageDark,
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        item.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: AppTheme.text,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          letterSpacing: -0.16,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(2),
                            child: LinearProgressIndicator(
                              value: item.progressFraction,
                              backgroundColor: AppTheme.well,
                              valueColor:
                                  const AlwaysStoppedAnimation(AppTheme.sage),
                              minHeight: 3,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _remaining(item),
                          style: const TextStyle(
                            fontFamily: AppTheme.text,
                            fontSize: 11,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ]),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  width: 44,
                  height: 44,
                  decoration: const BoxDecoration(
                    color: AppTheme.sage,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Color(0x477C3AED),
                        blurRadius: 16,
                        offset: Offset(0, 6),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.play_arrow_rounded,
                      color: Colors.white, size: 22),
                ),
              ]),
            ),
          ),
        );
      },
    );
  }

  /// "4 min left", or "Almost done" under a minute.
  ///
  /// Time remaining rather than a percentage: the question somebody
  /// glancing at this card is asking is whether they have time to finish
  /// it now, and 78% does not answer that.
  String _remaining(ContinueListeningItem item) {
    final left = item.durationSeconds - item.progressSeconds;
    if (left <= 60) return 'Almost done';
    return '${(left / 60).round()} min left';
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

/// Stands in for missing cover art at thumbnail size.
///
/// A flat tint, not the hero gradient: at 52px a two-stop gradient reads
/// as a smudge, and the tile only has to say "there is artwork here".
class _ArtFallback extends StatelessWidget {
  const _ArtFallback();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: AppTheme.sageSoft,
      child: Icon(Icons.music_note_rounded,
          color: AppTheme.sageLight, size: 22),
    );
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
      orElse: () => const SizedBox(height: 112),
      data: (categories) {
        if (categories.isEmpty) return const SizedBox.shrink();
        return SizedBox(
          height: 112,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: categories.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (_, i) {
              final c = categories[i];
              // The ramp cycles by position, so the row keeps its
              // light-to-dark rhythm however many categories the admin
              // has published. Keying it off the category id instead
              // would reshuffle the colours whenever one was renamed.
              final ramp = _browseRamps[i % _browseRamps.length];
              return GestureDetector(
                onTap: () => onTap(c),
                child: Container(
                  width: 112,
                  padding: const EdgeInsets.fromLTRB(12, 16, 12, 16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: ramp.fill,
                    ),
                    borderRadius: BorderRadius.circular(AppTheme.radiusRow),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        _categoryIcon(c.name, c.slug),
                        size: 24,
                        color: ramp.ink,
                      ),
                      const Spacer(),
                      Text(
                        c.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: AppTheme.text,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          letterSpacing: -0.14,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      if (c.audioCount > 0) ...[
                        const SizedBox(height: 2),
                        Text(
                          c.audioCount == 1
                              ? '1 session'
                              : '${c.audioCount} sessions',
                          style: const TextStyle(
                            fontFamily: AppTheme.text,
                            fontSize: 12,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
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

/// One step of the Browse row's colour ramp: the card's wash and the
/// ink its glyph is drawn in.
class _BrowseRamp {
  final List<Color> fill;
  final Color ink;
  const _BrowseRamp(this.fill, this.ink);
}

/// Three washes running light to dark, with the glyph darkening to keep
/// up. Each is the design's gradient at its stated opacity, flattened
/// against the lavender canvas — a translucent gradient over a
/// horizontally scrolling row would smear whatever slid beneath it.
const _browseRamps = [
  _BrowseRamp([Color(0xFFF5EFFE), Color(0xFFE8DDFB)], Color(0xFF7C3AED)),
  _BrowseRamp([Color(0xFFE7DCFA), Color(0xFFD5C4F5)], Color(0xFF5B21B6)),
  _BrowseRamp([Color(0xFFD8C9F3), Color(0xFFC5AEEE)], Color(0xFF3B1A78)),
];

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
      // 260, matching the loaded row exactly. It used to be 190, and the
      // 70px difference was the second half of the scroll stutter: when
      // the data arrived, everything above the viewport grew by 70px and
      // the scroll offset shifted under the user's finger. That reads as
      // the list catching on something. Every other row on this screen
      // already reserved its true height; this was the one that did not,
      // and it is the one the stutter was reported against.
      orElse: () => const SizedBox(height: 260),
      data: (courses) {
        if (courses.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: _EmptyHint(
              icon: kEducationFramingEnabled
                  ? Icons.school_outlined
                  : Icons.video_library_outlined,
              text: kEducationFramingEnabled
                  ? 'Courses will appear here once they are published.'
                  : 'New releases will appear here once they are published.',
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
            RemoteImage(
              url: course.coverImageUrl,
              fallback: const _MiniCover(),
            ),

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
                      course.owned
                          ? (kEducationFramingEnabled ? 'Enrolled' : 'Yours')
                          : kPurchaseUiEnabled || course.isFree
                              ? course.priceLabel
                              : 'Locked',
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
                          course.isStarted
                              ? 'Continue'
                              : (kEducationFramingEnabled
                                  ? 'Start Course'
                                  : 'Watch'),
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
      orElse: () => const SizedBox(height: 200),
      data: (audios) {
        if (audios.isEmpty) return const SizedBox.shrink();

        return SizedBox(
          // Fixed rather than intrinsic: every cover starts at the same
          // height so the row reads as a shelf, and a two-line title on
          // one card can't shunt its neighbour's caption down.
          height: 200,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: audios.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (_, i) {
              final audio = audios[i];
              final locked = audio.isPremium && access?.hasAccess != true;

              // Cover, then caption on the canvas — no card around the
              // pair. The design carries these on the page itself, which
              // is what lets two of them sit side by side without the
              // row turning into a wall of boxes.
              return GestureDetector(
                onTap: () => onPlay(audio),
                child: SizedBox(
                  width: 168,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        height: 152,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          borderRadius:
                              BorderRadius.circular(AppTheme.radiusRow),
                          boxShadow: AppTheme.tileShadow,
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: Stack(fit: StackFit.expand, children: [
                          RemoteImage(
                            url: audio.coverArtUrl,
                            fallback: const _MiniCover(),
                          ),
                          if (locked) const PremiumLockBadge(),
                          const Positioned(
                            right: 10,
                            bottom: 10,
                            child: _PlayBubble(),
                          ),
                        ]),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        audio.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: AppTheme.text,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          letterSpacing: -0.15,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      Text(
                        _audioMeta(audio),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: AppTheme.text,
                          fontSize: 13,
                          color: AppTheme.textSecondary,
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

  /// "Anurag Rishi · 12 min", dropping whichever half is missing.
  ///
  /// One caption line rather than an artist line plus a duration pill:
  /// the pill was a second piece of chrome under a cover that already
  /// has a play button on it.
  String _audioMeta(AudioSummary audio) {
    final parts = <String>[
      if (audio.artist != null && audio.artist!.trim().isNotEmpty)
        audio.artist!.trim(),
      if (audio.durationSeconds != null)
        '${(audio.durationSeconds! / 60).round()} min',
    ];
    return parts.join(' · ');
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
