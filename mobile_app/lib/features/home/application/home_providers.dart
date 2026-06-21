import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/supabase_client_provider.dart';
import '../data/datasources/home_remote_datasource.dart';
import '../data/repositories/home_repository_impl.dart';
import '../domain/entities/audio_summary.dart';
import '../domain/entities/category_summary.dart';
import '../domain/entities/continue_listening_item.dart';
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

final featuredAudiosProvider = FutureProvider.autoDispose<List<AudioSummary>>(
  (ref) => ref.watch(homeRepositoryProvider).getFeaturedAudios(),
);

final recentlyAddedProvider = FutureProvider.autoDispose<List<AudioSummary>>(
  (ref) => ref.watch(homeRepositoryProvider).getRecentlyAdded(),
);

final continueListeningProvider =
    FutureProvider.autoDispose<List<ContinueListeningItem>>(
  (ref) => ref.watch(homeRepositoryProvider).getContinueListening(),
);

final categoriesProvider = FutureProvider.autoDispose<List<CategorySummary>>(
  (ref) => ref.watch(homeRepositoryProvider).getCategories(),
);

final searchAudiosProvider =
    FutureProvider.autoDispose.family<List<AudioSummary>, String>(
  (ref, query) => ref.watch(homeRepositoryProvider).searchAudios(query),
);

final categoryAudiosProvider =
    FutureProvider.autoDispose.family<List<AudioSummary>, String>(
  (ref, categoryId) =>
      ref.watch(homeRepositoryProvider).getAudiosByCategory(categoryId),
);
