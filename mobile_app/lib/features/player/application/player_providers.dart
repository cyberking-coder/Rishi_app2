import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/supabase_client_provider.dart';
import '../data/datasources/player_remote_datasource.dart';
import '../data/repositories/player_repository_impl.dart';
import '../domain/repositories/player_repository.dart';
import 'ott_player_controller.dart';

final playerRemoteDataSourceProvider = Provider<PlayerRemoteDataSource>((ref) {
  return PlayerRemoteDataSource(ref.watch(supabaseClientProvider));
});

final playerRepositoryProvider = Provider<PlayerRepository>((ref) {
  return PlayerRepositoryImpl(ref.watch(playerRemoteDataSourceProvider));
});

/// One controller instance per videoId, disposed automatically when the
/// player screen for that video is no longer being watched.
final ottPlayerControllerProvider =
    ChangeNotifierProvider.autoDispose.family<OttPlayerController, String>(
  (ref, videoId) {
    final controller = OttPlayerController(
      videoId,
      ref.watch(playerRepositoryProvider),
    );
    controller.initialize();
    ref.onDispose(controller.dispose);
    return controller;
  },
);
