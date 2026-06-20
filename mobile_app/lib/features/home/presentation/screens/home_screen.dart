import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_theme.dart';
import '../../../../app/widgets/lotus_logo.dart';
import '../../../../app/widgets/soft_background.dart';
import '../../../../core/utils/responsive.dart';
import '../../../access/application/access_providers.dart';
import '../../../access/domain/access_state.dart';
import '../../../access/presentation/access_expired_view.dart';
import '../../../access/presentation/next_event_popup.dart';
import '../../../audio/application/audio_providers.dart';
import '../../../audio/domain/entities/audio_track.dart';
import '../../../downloads/application/download_providers.dart';
import '../../application/home_providers.dart';
import '../../domain/entities/audio_summary.dart';
import '../../domain/entities/category_summary.dart';
import '../../domain/entities/continue_listening_item.dart';
import '../widgets/audio_card.dart';
import '../widgets/category_chip.dart';
import '../widgets/fade_slide_in.dart';
import '../widgets/section_error.dart';
import '../widgets/section_header.dart';
import '../widgets/section_placeholder.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  // Ensures the next-event pop-up is shown at most once per app session.
  bool _popupShown = false;
  // Ensures downloads are purged at most once after detecting expiry.
  bool _purged = false;

  void _onAccess(AccessState access) {
    // Access lapsed: wipe any offline downloads (best-effort).
    if (access.isExpired && !_purged) {
      _purged = true;
      ref.read(downloadRepositoryProvider).purgeAll();
      return;
    }
    // Still has access and a pop-up is due: show it once, after this frame.
    if (access.hasAccess && access.shouldShowPopup && !_popupShown) {
      _popupShown = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) NextEventPopup.show(context, access);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final accessAsync = ref.watch(accessStateProvider);
    final access = accessAsync.valueOrNull;
    if (access != null) _onAccess(access);

    // Fail open while access is unknown (loading/error): playback is still
    // enforced server-side, so the worst case is briefly showing titles.
    final expired = access?.isExpired ?? false;

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Stack(
        children: [
          const SoftBackground(),
          CustomScrollView(
            slivers: [
              SliverAppBar(
                backgroundColor: Colors.transparent,
                pinned: true,
                titleSpacing: 16,
                title: Row(
                  children: [
                    const LotusLogo(size: 26),
                    const SizedBox(width: 10),
                    Text(
                      'Anurag _Rishi',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 20,
                        letterSpacing: 0.2,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ],
                ),
                actions: [
                  if (!expired)
                    IconButton(
                      tooltip: 'Downloads',
                      onPressed: () => context.push('/downloads'),
                      icon: const Icon(Icons.download_outlined),
                    ),
                  IconButton(
                    tooltip: 'Profile',
                    onPressed: () => context.push('/profile'),
                    icon: const Icon(Icons.person_outline),
                  ),
                  const SizedBox(width: 8),
                ],
              ),
              if (expired)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: AccessExpiredView(access: access!),
                )
              else
                SliverToBoxAdapter(
                  child: SafeArea(
                    top: false,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const _GreetingHero(),
                        if (access?.daysLeft != null && access!.daysLeft! <= 7)
                          _AccessBanner(daysLeft: access.daysLeft!),
                        const SizedBox(height: 8),
                        _ContinueListeningSection(),
                        const SizedBox(height: 24),
                        _FeaturedAudiosSection(),
                        const SizedBox(height: 24),
                        _RecentlyAddedSection(),
                        const SizedBox(height: 24),
                        _CategoriesSection(),
                        const SizedBox(height: 32),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// A warm, time-aware welcome card at the top of the home feed.
class _GreetingHero extends StatelessWidget {
  const _GreetingHero();

  String get _greeting {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AppTheme.heroGradient,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppTheme.accent.withValues(alpha: 0.28),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$_greeting 🙏',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Take a breath,\nand begin within.',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    height: 1.25,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.22),
              shape: BoxShape.circle,
            ),
            child: const Center(child: LotusLogo(size: 30, color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

/// A gentle reminder shown in the final week of the access window.
class _AccessBanner extends StatelessWidget {
  final int daysLeft;
  const _AccessBanner({required this.daysLeft});

  @override
  Widget build(BuildContext context) {
    final label = daysLeft <= 0
        ? 'Access ends today'
        : daysLeft == 1
            ? '1 day of access left'
            : '$daysLeft days of access left';
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.accentSoft,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.access_time, size: 18, color: AppTheme.accent),
          const SizedBox(width: 10),
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppTheme.accent,
            ),
          ),
        ],
      ),
    );
  }
}

class _ContinueListeningSection extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(continueListeningProvider);

    return async.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (items) {
        if (items.isEmpty) return const SizedBox.shrink();
        return FadeSlideIn(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionHeader(title: 'Continue Listening'),
              SizedBox(
                height: Responsive.squareCardWidth(context) + 50,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: Responsive.pageHorizontalPadding(context),
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final ContinueListeningItem item = items[index];
                    return _ContinueListeningCard(
                      item: item,
                      onTap: () {
                        ref.read(audioHandlerProvider).playSingleTrack(
                              AudioTrack(
                                id: item.audioId,
                                title: item.title,
                                artist: item.teacher,
                                coverArtUrl: item.coverArtUrl,
                                durationSeconds: item.durationSeconds,
                              ),
                            );
                        context.push('/now-playing');
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ContinueListeningCard extends StatelessWidget {
  final ContinueListeningItem item;
  final VoidCallback onTap;

  const _ContinueListeningCard({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final size = Responsive.squareCardWidth(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        margin: const EdgeInsets.only(right: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: item.coverArtUrl != null
                      ? Image.network(
                          item.coverArtUrl!,
                          width: size,
                          height: size,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) =>
                              _placeholder(size),
                        )
                      : _placeholder(size),
                ),
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: LinearProgressIndicator(
                    value: item.progressFraction,
                    backgroundColor: Colors.white24,
                    valueColor: const AlwaysStoppedAnimation(AppTheme.accent),
                    minHeight: 3,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              item.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }

  Widget _placeholder(double size) => Container(
        width: size,
        height: size,
        color: AppTheme.surfaceElevated,
        child: const Icon(Icons.headphones, color: AppTheme.textSecondary),
      );
}

class _FeaturedAudiosSection extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(featuredAudiosProvider);

    return async.when(
      loading: () => const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(title: 'Featured'),
          SectionPlaceholder(square: true),
        ],
      ),
      error: (_, __) =>
          SectionError(onRetry: () => ref.invalidate(featuredAudiosProvider)),
      data: (audios) => FadeSlideIn(
        delay: const Duration(milliseconds: 60),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionHeader(title: 'Featured'),
            _AudioRow(audios: audios, ref: ref),
          ],
        ),
      ),
    );
  }
}

class _RecentlyAddedSection extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(recentlyAddedProvider);

    return async.when(
      loading: () => const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(title: 'Recently Added'),
          SectionPlaceholder(square: true),
        ],
      ),
      error: (_, __) =>
          SectionError(onRetry: () => ref.invalidate(recentlyAddedProvider)),
      data: (audios) => FadeSlideIn(
        delay: const Duration(milliseconds: 120),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionHeader(title: 'Recently Added'),
            _AudioRow(audios: audios, ref: ref),
          ],
        ),
      ),
    );
  }
}

class _AudioRow extends StatelessWidget {
  final List<AudioSummary> audios;
  final WidgetRef ref;

  const _AudioRow({required this.audios, required this.ref});

  @override
  Widget build(BuildContext context) {
    if (audios.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 16),
        child: Text('Nothing here yet.',
            style: TextStyle(color: AppTheme.textSecondary)),
      );
    }

    return SizedBox(
      height: Responsive.squareCardWidth(context) + 50,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: Responsive.pageHorizontalPadding(context),
        itemCount: audios.length,
        itemBuilder: (context, index) {
          final AudioSummary audio = audios[index];
          return AudioCard(
            audio: audio,
            onTap: () {
              ref.read(audioHandlerProvider).playSingleTrack(
                    AudioTrack(
                      id: audio.id,
                      title: audio.title,
                      artist: audio.artist,
                      coverArtUrl: audio.coverArtUrl,
                      durationSeconds: audio.durationSeconds,
                    ),
                  );
              context.push('/now-playing');
            },
          );
        },
      ),
    );
  }
}

class _CategoriesSection extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(categoriesProvider);

    return async.when(
      loading: () => const SizedBox(height: 40),
      error: (_, __) =>
          SectionError(onRetry: () => ref.invalidate(categoriesProvider)),
      data: (categories) => FadeSlideIn(
        delay: const Duration(milliseconds: 180),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionHeader(title: 'Categories'),
            Padding(
              padding: Responsive.pageHorizontalPadding(context),
              child: Wrap(
                spacing: 0,
                runSpacing: 10,
                children: categories
                    .map((CategorySummary c) =>
                        CategoryChip(category: c, onTap: () {}))
                    .toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
