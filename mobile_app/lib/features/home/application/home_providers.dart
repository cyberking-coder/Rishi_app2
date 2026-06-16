import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/supabase_client_provider.dart';
import '../data/datasources/home_remote_datasource.dart';
import '../data/repositories/home_repository_impl.dart';
import '../domain/entities/audio_summary.dart';
import '../domain/entities/category_summary.dart';
import '../domain/entities/continue_watching_item.dart';
import '../domain/entities/video_summary.dart';
import '../domain/repositories/home_repository.dart';

final homeRemoteDataSourceProvider = Provider<HomeRemoteDataSource>((ref) {
  return HomeRemoteDataSource(ref.watch(supabaseClientProvider));
});

final homeRepositoryProvider = Provider<HomeRepository>((ref) {
  return HomeRepositoryImpl(
    ref.watch(homeRemoteDataSourceProvider),
    ref.watch(supabaseClientProvider),
  );
});

// Each section is its own FutureProvider so the screen can render and
// animate sections in independently as their data arrives, instead of
// blocking the whole page on the slowest query.

final featuredVideosProvider = FutureProvider.autoDispose<List<VideoSummary>>(
  (ref) => ref.watch(homeRepositoryProvider).getFeaturedVideos(),
);

final featuredAudiosProvider = FutureProvider.autoDispose<List<AudioSummary>>(
  (ref) => ref.watch(homeRepositoryProvider).getFeaturedAudios(),
);

final recentlyAddedProvider = FutureProvider.autoDispose<List<VideoSummary>>(
  (ref) => ref.watch(homeRepositoryProvider).getRecentlyAdded(),
);

final continueWatchingProvider =
    FutureProvider.autoDispose<List<ContinueWatchingItem>>(
  (ref) => ref.watch(homeRepositoryProvider).getContinueWatching(),
);

final categoriesProvider = FutureProvider.autoDispose<List<CategorySummary>>(
  (ref) => ref.watch(homeRepositoryProvider).getCategories(),
);
