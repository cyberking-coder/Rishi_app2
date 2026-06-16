import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_theme.dart';
import '../../../../core/utils/responsive.dart';
import '../../application/home_providers.dart';
import '../../domain/entities/audio_summary.dart';
import '../../domain/entities/category_summary.dart';
import '../../domain/entities/continue_watching_item.dart';
import '../../domain/entities/video_summary.dart';
import '../widgets/audio_card.dart';
import '../widgets/category_chip.dart';
import '../widgets/continue_watching_card.dart';
import '../widgets/fade_slide_in.dart';
import '../widgets/poster_card.dart';
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
              'OTT',
              style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: 1),
            ),
            actions: [
              IconButton(
                onPressed: () {},
                icon: const Icon(Icons.search),
              ),
              IconButton(
                onPressed: () {},
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
                  _ContinueWatchingSection(),
                  const SizedBox(height: 24),
                  _FeaturedVideosSection(),
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

class _ContinueWatchingSection extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(continueWatchingProvider);

    return async.when(
      loading: () => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(title: 'Continue Watching'),
          const SectionPlaceholder(),
        ],
      ),
      error: (_, __) => SectionError(
        onRetry: () => ref.invalidate(continueWatchingProvider),
      ),
      data: (items) {
        if (items.isEmpty) return const SizedBox.shrink();
        return FadeSlideIn(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionHeader(title: 'Continue Watching'),
              SizedBox(
                height: Responsive.posterCardHeight(context) * 0.8,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: Responsive.pageHorizontalPadding(context),
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final item = items[index];
                    return ContinueWatchingCard(
                      item: item,
                      onTap: item.type == ContinueWatchingType.video
                          ? () => context.push('/player/${item.contentId}')
                          : () {},
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

class _FeaturedVideosSection extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(featuredVideosProvider);

    return async.when(
      loading: () => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          SectionHeader(title: 'Featured Videos'),
          SectionPlaceholder(),
        ],
      ),
      error: (_, __) =>
          SectionError(onRetry: () => ref.invalidate(featuredVideosProvider)),
      data: (videos) => FadeSlideIn(
        delay: const Duration(milliseconds: 60),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionHeader(title: 'Featured Videos'),
            _VideoRow(videos: videos),
          ],
        ),
      ),
    );
  }
}

class _FeaturedAudiosSection extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(featuredAudiosProvider);

    return async.when(
      loading: () => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          SectionHeader(title: 'Featured Audios'),
          SectionPlaceholder(square: true),
        ],
      ),
      error: (_, __) =>
          SectionError(onRetry: () => ref.invalidate(featuredAudiosProvider)),
      data: (audios) => FadeSlideIn(
        delay: const Duration(milliseconds: 120),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionHeader(title: 'Featured Audios'),
            SizedBox(
              height: Responsive.squareCardWidth(context) + 50,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: Responsive.pageHorizontalPadding(context),
                itemCount: audios.length,
                itemBuilder: (context, index) {
                  final AudioSummary audio = audios[index];
                  return AudioCard(audio: audio, onTap: () {});
                },
              ),
            ),
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
      loading: () => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          SectionHeader(title: 'Recently Added'),
          SectionPlaceholder(),
        ],
      ),
      error: (_, __) =>
          SectionError(onRetry: () => ref.invalidate(recentlyAddedProvider)),
      data: (videos) => FadeSlideIn(
        delay: const Duration(milliseconds: 180),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionHeader(title: 'Recently Added'),
            _VideoRow(videos: videos),
          ],
        ),
      ),
    );
  }
}

class _CategoriesSection extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(categoriesProvider);

    return async.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(horizontal: 16),
        child: SizedBox(height: 40),
      ),
      error: (_, __) =>
          SectionError(onRetry: () => ref.invalidate(categoriesProvider)),
      data: (categories) => FadeSlideIn(
        delay: const Duration(milliseconds: 240),
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
                    .map((CategorySummary category) =>
                        CategoryChip(category: category, onTap: () {}))
                    .toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VideoRow extends StatelessWidget {
  final List<VideoSummary> videos;

  const _VideoRow({required this.videos});

  @override
  Widget build(BuildContext context) {
    if (videos.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 16),
        child: Text('Nothing here yet.',
            style: TextStyle(color: AppTheme.textSecondary)),
      );
    }

    return SizedBox(
      height: Responsive.posterCardHeight(context) + 28,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: Responsive.pageHorizontalPadding(context),
        itemCount: videos.length,
        itemBuilder: (context, index) => PosterCard(
          video: videos[index],
          onTap: () => context.push('/player/${videos[index].id}'),
        ),
      ),
    );
  }
}
