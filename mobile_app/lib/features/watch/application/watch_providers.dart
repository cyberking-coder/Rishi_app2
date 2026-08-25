import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/supabase_client_provider.dart';
import '../data/datasources/youtube_remote_datasource.dart';
import '../domain/entities/youtube_video.dart';

final youtubeRemoteDataSourceProvider =
    Provider<YoutubeRemoteDataSource>((ref) {
  return YoutubeRemoteDataSource(ref.watch(supabaseClientProvider));
});

/// Kept alive — see the note on the home providers. This one sits at
/// the very bottom of Home, so it is the row most likely to be scrolled
/// past and back to.
final youtubeVideosProvider =
    FutureProvider.autoDispose<List<YoutubeVideo>>((ref) {
  ref.keepAlive();
  return ref.watch(youtubeRemoteDataSourceProvider).getVideos();
});
