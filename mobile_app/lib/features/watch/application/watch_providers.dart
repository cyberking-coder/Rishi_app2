import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/supabase_client_provider.dart';
import '../data/datasources/youtube_remote_datasource.dart';
import '../domain/entities/youtube_video.dart';

final youtubeRemoteDataSourceProvider =
    Provider<YoutubeRemoteDataSource>((ref) {
  return YoutubeRemoteDataSource(ref.watch(supabaseClientProvider));
});

final youtubeVideosProvider =
    FutureProvider.autoDispose<List<YoutubeVideo>>((ref) {
  return ref.watch(youtubeRemoteDataSourceProvider).getVideos();
});
