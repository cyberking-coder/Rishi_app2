import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/supabase_client_provider.dart';
import '../../audio/domain/entities/audio_track.dart';
import '../data/favorites_remote_datasource.dart';

final favoritesDataSourceProvider = Provider<FavoritesRemoteDataSource>((ref) {
  return FavoritesRemoteDataSource(ref.watch(supabaseClientProvider));
});

/// The set of favourited audio ids — drives the heart toggle everywhere.
/// Optimistically updated on toggle so the heart flips instantly, then
/// reconciled with the server; the audio list provider is refreshed too.
class FavoriteIdsController extends AsyncNotifier<Set<String>> {
  FavoritesRemoteDataSource get _ds => ref.read(favoritesDataSourceProvider);

  @override
  Future<Set<String>> build() => _ds.favoriteIds();

  bool isFavorite(String audioId) =>
      state.valueOrNull?.contains(audioId) ?? false;

  Future<void> toggle(String audioId) async {
    final current = {...(state.valueOrNull ?? <String>{})};
    final wasFavorite = current.contains(audioId);

    // Optimistic flip.
    if (wasFavorite) {
      current.remove(audioId);
    } else {
      current.add(audioId);
    }
    state = AsyncData(current);

    try {
      if (wasFavorite) {
        await _ds.remove(audioId);
      } else {
        await _ds.add(audioId);
      }
      // The Favourites list depends on this set — refresh it.
      ref.invalidate(favoriteAudiosProvider);
    } catch (_) {
      // Roll back on failure so the heart reflects reality.
      final reverted = {...current};
      if (wasFavorite) {
        reverted.add(audioId);
      } else {
        reverted.remove(audioId);
      }
      state = AsyncData(reverted);
    }
  }
}

final favoriteIdsProvider =
    AsyncNotifierProvider<FavoriteIdsController, Set<String>>(
        FavoriteIdsController.new);

/// The favourited audios as playable tracks, newest first — for the screen.
final favoriteAudiosProvider = FutureProvider<List<AudioTrack>>((ref) async {
  final rows = await ref.watch(favoritesDataSourceProvider).favoriteAudios();
  return rows.map(AudioTrack.fromMap).toList();
});
