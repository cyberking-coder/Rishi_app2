import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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
import '../widgets/premium_lock.dart';

// ── Design tokens ─────────────────────────────────────────────────────────────
const _kBg         = Color(0xFF12082E);
const _kSurface    = Color(0xFF1C1040);
const _kAccent     = Color(0xFF8B5CF6);
const _kPink       = Color(0xFFEC4899);
const _kTextPri    = Colors.white;
const _kTextSec    = Color(0xFFB0A8CC);
const _kSearch     = Color(0xFF1A0F38);

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  bool _popupShown = false;
  bool _purged = false;

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

  bool _starting = false;

  Future<void> _playAudio(AudioSummary audio) async {
    if (_starting) return; // guard against a double-tap opening twice
    final access = ref.read(accessStateProvider).valueOrNull;
    if (audio.isPremium && access?.hasAccess != true) {
      showPremiumLockedMessage(context);
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    } finally {
      _starting = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final accessAsync = ref.watch(accessStateProvider);
    final access = accessAsync.valueOrNull;
    if (access != null) _onAccess(access);
    // Only a real (possibly unlimited) retreat window shows a countdown —
    // a free-tier user was never granted one, so there's nothing to count
    // down to zero forever.
    final daysLeft =
        access?.tier == UserTier.retreat ? access?.daysLeft : null;

    // Real display name from profile
    final profile = ref.watch(userProfileProvider).valueOrNull;
    final rawName = profile?.displayName?.trim().isNotEmpty == true
        ? profile!.displayName!.trim()
        : (profile?.email.split('@').first ?? 'there');
    final username = rawName.isEmpty ? 'there' : rawName;

    final greeting = _greeting();

    return Scaffold(
      backgroundColor: _kBg,
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            // ── Header ──
            _Header(
              username: username,
              greeting: greeting,
              daysLeft: daysLeft,
              onProfile: () => context.push('/profile'),
              onDownloads: () => context.push('/downloads'),
            ),
            const SizedBox(height: 14),

            // ── Search bar ──
            _SearchBar(onTap: () => context.push('/search')),
            const SizedBox(height: 18),

            // ── Daily Meditation card ──
            _DailyCard(onPlay: _playAudio),
            const SizedBox(height: 22),

            // ── Featured For You ──
            _SectionTitle(
              title: 'Featured For You',
              action: 'See All',
              onAction: () => context.push('/search'),
            ),
            const SizedBox(height: 12),
            _FeaturedRow(onPlay: _playAudio),
            const SizedBox(height: 22),

            // ── Categories ──
            const _SectionTitle(title: 'Categories'),
            const SizedBox(height: 12),
            _CategoriesRow(
              onTap: (c) => context.push('/category/${c.id}', extra: c.name),
            ),
            const SizedBox(height: 22),

            // ── Continue Listening bar ──
            _ContinueBar(
              onTap: (item) async {
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
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(e.toString())),
                  );
                }
              },
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good Morning';
    if (h < 17) return 'Good Afternoon';
    return 'Good Evening';
  }
}

// ── Header ────────────────────────────────────────────────────────────────────
class _Header extends StatelessWidget {
  final String username;
  final String greeting;
  final int? daysLeft;
  final VoidCallback onProfile;
  final VoidCallback onDownloads;

  const _Header({
    required this.username,
    required this.greeting,
    required this.daysLeft,
    required this.onProfile,
    required this.onDownloads,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    RichText(
                      text: TextSpan(
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: _kTextPri,
                        ),
                        children: [
                          TextSpan(text: 'Hi, $username '),
                          const TextSpan(text: '👋'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(greeting,
                        style: const TextStyle(
                            fontSize: 13, color: _kTextSec)),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.download_outlined, color: _kTextSec),
                onPressed: onDownloads,
              ),
              GestureDetector(
                onTap: onProfile,
                child: Container(
                  width: 40,
                  height: 40,
                  margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [_kAccent, _kPink],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: _kAccent.withValues(alpha: 0.4),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.person,
                      color: Colors.white, size: 22),
                ),
              ),
            ],
          ),
          if (daysLeft != null && daysLeft! <= 7) ...[
            const SizedBox(height: 10),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: _kPink.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: _kPink.withValues(alpha: 0.4), width: 1),
              ),
              child: Row(children: [
                const Icon(Icons.access_time,
                    size: 16, color: _kPink),
                const SizedBox(width: 8),
                Text(
                  daysLeft! <= 0
                      ? 'Access ends today'
                      : daysLeft == 1
                          ? '1 day of access left'
                          : '$daysLeft days of access left',
                  style: const TextStyle(
                      fontSize: 12,
                      color: _kPink,
                      fontWeight: FontWeight.w600),
                ),
              ]),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Search bar ────────────────────────────────────────────────────────────────
class _SearchBar extends StatelessWidget {
  final VoidCallback onTap;
  const _SearchBar({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20),
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: _kSearch,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: Colors.white.withValues(alpha: 0.08), width: 1),
        ),
        child: Row(children: [
          Icon(Icons.search,
              color: _kTextSec.withValues(alpha: 0.7), size: 20),
          const SizedBox(width: 10),
          Text('Search meditation, music, etc...',
              style: TextStyle(
                  fontSize: 14,
                  color: _kTextSec.withValues(alpha: 0.7))),
        ]),
      ),
    );
  }
}

// ── Daily Meditation card ─────────────────────────────────────────────────────
class _DailyCard extends ConsumerWidget {
  final void Function(AudioSummary) onPlay;
  const _DailyCard({required this.onPlay});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(featuredAudiosProvider);
    final access = ref.watch(accessStateProvider).valueOrNull;
    return async.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (audios) {
        if (audios.isEmpty) return const SizedBox.shrink();
        final audio = audios.first;
        final locked = audio.isPremium && access?.hasAccess != true;
        final mins = audio.durationSeconds != null
            ? '${(audio.durationSeconds! ~/ 60)} min'
            : '';
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 20),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF2A1A5E), Color(0xFF1C1040)],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
                color: _kAccent.withValues(alpha: 0.25), width: 1),
          ),
          child: Row(children: [
            // Thumbnail
            SizedBox(
              width: 72,
              height: 72,
              child: Stack(children: [
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [_kPink, _kAccent],
                    ),
                  ),
                  child: audio.coverArtUrl != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Image.network(audio.coverArtUrl!,
                              fit: BoxFit.cover))
                      : const Icon(Icons.self_improvement,
                      color: Colors.white, size: 36),
                ),
                if (locked) const PremiumLockBadge(),
              ]),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Daily Meditation',
                      style:
                          TextStyle(fontSize: 11, color: _kAccent)),
                  const SizedBox(height: 4),
                  Text(audio.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: _kTextPri)),
                  const SizedBox(height: 4),
                  Text(
                    [if (mins.isNotEmpty) mins, if (audio.artist != null) audio.artist!]
                        .join(' · '),
                    style: const TextStyle(
                        fontSize: 11, color: _kTextSec),
                  ),
                  const SizedBox(height: 10),
                  GestureDetector(
                    onTap: () => onPlay(audio),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 18, vertical: 7),
                      decoration: BoxDecoration(
                        color: _kAccent,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: _kAccent.withValues(alpha: 0.4),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Text(locked ? 'Locked' : 'Play Now',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600)),
                    ),
                  ),
                ],
              ),
            ),
          ]),
        );
      },
    );
  }
}

// ── Section title row ─────────────────────────────────────────────────────────
class _SectionTitle extends StatelessWidget {
  final String title;
  final String? action;
  final VoidCallback? onAction;

  const _SectionTitle({required this.title, this.action, this.onAction});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(children: [
        Expanded(
          child: Text(title,
              style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: _kTextPri)),
        ),
        if (action != null)
          GestureDetector(
            onTap: onAction,
            child: Text(action!,
                style: const TextStyle(
                    fontSize: 13,
                    color: _kAccent,
                    fontWeight: FontWeight.w500)),
          ),
      ]),
    );
  }
}

// ── Featured For You — horizontal row of cards ────────────────────────────────
class _FeaturedRow extends ConsumerWidget {
  final void Function(AudioSummary) onPlay;
  const _FeaturedRow({required this.onPlay});

  static const List<List<Color>> _gradients = [
    [Color(0xFF1E3A8A), Color(0xFF312E81)],
    [Color(0xFF6D28D9), Color(0xFF4C1D95)],
    [Color(0xFF7C3AED), Color(0xFF9333EA)],
    [Color(0xFF0C4A6E), Color(0xFF0E7490)],
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(featuredAudiosProvider);
    final access = ref.watch(accessStateProvider).valueOrNull;
    return async.when(
      loading: () => const SizedBox(
          height: 120,
          child: Center(
              child: CircularProgressIndicator(
                  color: _kAccent, strokeWidth: 2))),
      error: (_, __) => const SizedBox.shrink(),
      data: (audios) {
        if (audios.isEmpty) return const SizedBox.shrink();
        return SizedBox(
          height: 120,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding:
                const EdgeInsets.symmetric(horizontal: 20),
            itemCount: audios.length,
            itemBuilder: (context, i) {
              final audio = audios[i];
              final locked = audio.isPremium && access?.hasAccess != true;
              final grad = _gradients[i % _gradients.length];
              return GestureDetector(
                onTap: () => onPlay(audio),
                child: Container(
                  width: 110,
                  margin: const EdgeInsets.only(right: 12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: audio.coverArtUrl != null
                          ? grad
                          : grad,
                    ),
                  ),
                  child: Stack(fit: StackFit.expand, children: [
                    if (audio.coverArtUrl != null)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Image.network(
                            audio.coverArtUrl!,
                            fit: BoxFit.cover),
                      ),
                    // Dark overlay for text readability
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withValues(alpha: 0.6),
                          ],
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 10,
                      left: 10,
                      right: 6,
                      child: Text(audio.title,
                          maxLines: 2,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              height: 1.3)),
                    ),
                    if (locked) const PremiumLockBadge(),
                  ]),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

// ── Categories row ────────────────────────────────────────────────────────────
class _CategoriesRow extends ConsumerWidget {
  final void Function(CategorySummary) onTap;
  const _CategoriesRow({required this.onTap});

  static const List<IconData> _icons = [
    Icons.bedtime_outlined,
    Icons.self_improvement,
    Icons.psychology_outlined,
    Icons.favorite_border,
  ];

  static const List<Color> _colors = [
    Color(0xFF8B5CF6),
    Color(0xFFEC4899),
    Color(0xFFF59E0B),
    Color(0xFF10B981),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(categoriesProvider);
    return async.when(
      loading: () =>
          const SizedBox(height: 90),
      error: (_, __) => const SizedBox.shrink(),
      data: (cats) {
        if (cats.isEmpty) return const SizedBox.shrink();
        return SizedBox(
          height: 90,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: cats.length,
            itemBuilder: (context, i) {
              final cat = cats[i];
              final color = _colors[i % _colors.length];
              final icon = _icons[i % _icons.length];
              return GestureDetector(
                onTap: () => onTap(cat),
                child: Container(
                  width: 76,
                  margin: const EdgeInsets.only(right: 12),
                  child: Column(
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                              color:
                                  color.withValues(alpha: 0.4),
                              width: 1),
                        ),
                        child: Icon(icon, color: color, size: 26),
                      ),
                      const SizedBox(height: 6),
                      Text(cat.name,
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 11,
                              color: _kTextSec)),
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

// ── Continue Listening pinned bar ─────────────────────────────────────────────
class _ContinueBar extends ConsumerWidget {
  final void Function(ContinueListeningItem) onTap;
  const _ContinueBar({required this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(continueListeningProvider);
    return async.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (items) {
        if (items.isEmpty) return const SizedBox.shrink();
        final item = items.first;
        final minsLeft = item.durationSeconds > 0 && item.progressSeconds > 0
            ? ((item.durationSeconds - item.progressSeconds) ~/ 60)
            : null;
        return GestureDetector(
          onTap: () => onTap(item),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 20),
            padding: const EdgeInsets.symmetric(
                horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: _kSurface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                  color: _kAccent.withValues(alpha: 0.3), width: 1),
            ),
            child: Row(children: [
              // Thumbnail
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  gradient: const LinearGradient(
                      colors: [_kAccent, _kPink]),
                ),
                child: item.coverArtUrl != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.network(item.coverArtUrl!,
                            fit: BoxFit.cover))
                    : const Icon(Icons.headphones,
                        color: Colors.white, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Continue Listening',
                        style: TextStyle(
                            fontSize: 10,
                            color: _kAccent,
                            fontWeight: FontWeight.w500)),
                    const SizedBox(height: 2),
                    Text(
                      minsLeft != null
                          ? '${item.title} · $minsLeft min left'
                          : item.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: _kTextPri),
                    ),
                    if (item.progressFraction > 0) ...[
                      const SizedBox(height: 5),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: item.progressFraction,
                          backgroundColor:
                              Colors.white.withValues(alpha: 0.1),
                          valueColor:
                              const AlwaysStoppedAnimation(_kAccent),
                          minHeight: 3,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _kAccent,
                  boxShadow: [
                    BoxShadow(
                      color: _kAccent.withValues(alpha: 0.4),
                      blurRadius: 10,
                    ),
                  ],
                ),
                child: const Icon(Icons.play_arrow,
                    color: Colors.white, size: 22),
              ),
            ]),
          ),
        );
      },
    );
  }
}
