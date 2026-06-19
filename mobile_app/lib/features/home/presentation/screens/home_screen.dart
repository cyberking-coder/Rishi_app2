import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_theme.dart';
import '../../../../core/utils/responsive.dart';
import '../../../audio/application/audio_providers.dart';
import '../../../audio/domain/entities/audio_track.dart';
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

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            backgroundColor: AppTheme.background,
            pinned: true,
            title: const Text(
              'Meditation',
              style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: 1),
            ),
            actions: [
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
          SliverToBoxAdapter(
            child: SafeArea(
              top: false,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
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
