import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_theme.dart';
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
import '../widgets/category_chip.dart';
import '../widgets/fade_slide_in.dart';
import '../widgets/grid_audio_card.dart';
import '../widgets/section_error.dart';
import '../widgets/section_header.dart';

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

  void _playAudio(AudioSummary audio) {
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
  }

  @override
  Widget build(BuildContext context) {
    final accessAsync = ref.watch(accessStateProvider);
    final access = accessAsync.valueOrNull;
    if (access != null) _onAccess(access);
    final expired = access?.isExpired ?? false;

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Stack(
        children: [
          const SoftBackground(),
          SafeArea(
            child: expired
                ? AccessExpiredView(access: access!)
                : CustomScrollView(
                    slivers: [
                      SliverToBoxAdapter(
                        child: _Header(
                          daysLeft: access?.daysLeft,
                          onProfile: () => context.push('/profile'),
                          onDownloads: () => context.push('/downloads'),
                        ),
                      ),
                      SliverToBoxAdapter(child: _ContinueListeningSection()),
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: SectionHeader(title: 'Find your focus'),
                        ),
                      ),
                      _FeaturedGrid(onPlay: _playAudio),
                      const SliverToBoxAdapter(child: SizedBox(height: 20)),
                      SliverToBoxAdapter(
                        child: SectionHeader(title: 'Recently Added'),
                      ),
                      _RecentlyAddedGrid(onPlay: _playAudio),
                      const SliverToBoxAdapter(child: SizedBox(height: 24)),
                      SliverToBoxAdapter(child: _CategoriesSection()),
                      const SliverToBoxAdapter(child: SizedBox(height: 32)),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final int? daysLeft;
  final VoidCallback onProfile;
  final VoidCallback onDownloads;

  const _Header({
    required this.daysLeft,
    required this.onProfile,
    required this.onDownloads,
  });

  String get _greeting {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good Morning!';
    if (h < 17) return 'Good Afternoon!';
    return 'Good Evening!';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  _greeting,
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Downloads',
                onPressed: onDownloads,
                icon: const Icon(Icons.download_outlined),
              ),
              const SizedBox(width: 4),
              GestureDetector(
                onTap: onProfile,
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    gradient: AppTheme.heroGradient,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.accent.withValues(alpha: 0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.person, color: Colors.white, size: 24),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'What would you like to focus on?',
            style: TextStyle(
              fontSize: 15,
              color: AppTheme.textSecondary,
            ),
          ),
          if (daysLeft != null && daysLeft! <= 7) ...[
            const SizedBox(height: 12),
            _AccessBanner(daysLeft: daysLeft!),
          ],
        ],
      ),
    );
  }
}

/// A 2-column grid of pastel audio cards.
class _FeaturedGrid extends ConsumerWidget {
  final void Function(AudioSummary) onPlay;
  const _FeaturedGrid({required this.onPlay});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(featuredAudiosProvider);
    return async.when(
      loading: () => const SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.all(40),
          child: Center(child: CircularProgressIndicator(color: AppTheme.accent)),
        ),
      ),
      error: (_, __) => SliverToBoxAdapter(
        child: SectionError(onRetry: () => ref.invalidate(featuredAudiosProvider)),
      ),
      data: (audios) => _AudioSliverGrid(audios: audios, onPlay: onPlay),
    );
  }
}

class _RecentlyAddedGrid extends ConsumerWidget {
  final void Function(AudioSummary) onPlay;
  const _RecentlyAddedGrid({required this.onPlay});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(recentlyAddedProvider);
    return async.when(
      loading: () => const SliverToBoxAdapter(child: SizedBox(height: 80)),
      error: (_, __) => SliverToBoxAdapter(
        child: SectionError(onRetry: () => ref.invalidate(recentlyAddedProvider)),
      ),
      data: (audios) => _AudioSliverGrid(audios: audios, onPlay: onPlay),
    );
  }
}

class _AudioSliverGrid extends StatelessWidget {
  final List<AudioSummary> audios;
  final void Function(AudioSummary) onPlay;

  const _AudioSliverGrid({required this.audios, required this.onPlay});

  @override
  Widget build(BuildContext context) {
    if (audios.isEmpty) {
      return const SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Text('Nothing here yet.',
              style: TextStyle(color: AppTheme.textSecondary)),
        ),
      );
    }
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 14,
          crossAxisSpacing: 14,
          childAspectRatio: 0.82,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, index) => FadeSlideIn(
            delay: Duration(milliseconds: 40 * (index % 4)),
            child: GridAudioCard(
              audio: audios[index],
              index: index,
              onTap: () => onPlay(audios[index]),
            ),
          ),
          childCount: audios.length,
        ),
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
              const SizedBox(height: 12),
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
                  borderRadius: BorderRadius.circular(16),
                  child: item.coverArtUrl != null
                      ? Image.network(
                          item.coverArtUrl!,
                          width: size,
                          height: size,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _placeholder(size),
                        )
                      : _placeholder(size),
                ),
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                        bottom: Radius.circular(16)),
                    child: LinearProgressIndicator(
                      value: item.progressFraction,
                      backgroundColor: Colors.white24,
                      valueColor:
                          const AlwaysStoppedAnimation(AppTheme.accent),
                      minHeight: 4,
                    ),
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

class _CategoriesSection extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(categoriesProvider);

    return async.when(
      loading: () => const SizedBox(height: 40),
      error: (_, __) =>
          SectionError(onRetry: () => ref.invalidate(categoriesProvider)),
      data: (categories) {
        if (categories.isEmpty) return const SizedBox.shrink();
        return FadeSlideIn(
          delay: const Duration(milliseconds: 120),
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
        );
      },
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
