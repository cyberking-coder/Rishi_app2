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


/// Why the home lists call `ref.keepAlive()`.
///
/// They are `autoDispose`, and the home screen is a plain `ListView`,
/// which unmounts children once they pass beyond its cache extent. So
/// scrolling to the bottom of Home disposed the rows near the top, which
/// dropped the last listener on their providers, which threw the data
/// away. Scrolling back up remounted them, re-created the provider, and
/// re-fetched over the network — every time, in both directions.
///
/// That is the "it sticks in the same place every time I scroll back up"
/// report. The stall is a network round trip, and it happens on a scroll
/// gesture rather than at a moment the user asked for anything.
///
/// keepAlive() holds the result after the last listener goes, so
/// scrolling is free. Freshness is unaffected: every one of these is
/// invalidated explicitly by the pull-to-refresh on Home, which is the
/// gesture that means "get me new data".
///
/// Deliberately NOT applied to the `.family` providers below. Their keys
/// are user input — a search string, a category id — so keeping every
/// one alive would be an unbounded cache of results nobody asked to
/// keep.
final featuredAudiosProvider = FutureProvider.autoDispose<List<AudioSummary>>(
  (ref) {
    ref.keepAlive();
    return ref.watch(homeRepositoryProvider).getFeaturedAudios();
  },
);

final recentlyAddedProvider = FutureProvider.autoDispose<List<AudioSummary>>(
  (ref) {
    ref.keepAlive();
    return ref.watch(homeRepositoryProvider).getRecentlyAdded();
  },
);

final continueListeningProvider =
    FutureProvider.autoDispose<List<ContinueListeningItem>>(
  (ref) {
    ref.keepAlive();
    return ref.watch(homeRepositoryProvider).getContinueListening();
  },
);

final categoriesProvider = FutureProvider.autoDispose<List<CategorySummary>>(
  (ref) {
    ref.keepAlive();
    return ref.watch(homeRepositoryProvider).getCategories();
  },
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
