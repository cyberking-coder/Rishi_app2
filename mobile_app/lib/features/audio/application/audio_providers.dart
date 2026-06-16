import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/supabase_client_provider.dart';
import '../data/datasources/audio_remote_datasource.dart';
import '../data/repositories/audio_repository_impl.dart';
import '../domain/repositories/audio_repository.dart';
import 'audio_player_handler.dart';

final audioRemoteDataSourceProvider = Provider<AudioRemoteDataSource>((ref) {
  return AudioRemoteDataSource(ref.watch(supabaseClientProvider));
});

final audioRepositoryProvider = Provider<AudioRepository>((ref) {
  return AudioRepositoryImpl(ref.watch(audioRemoteDataSourceProvider));
});

/// The handler is constructed once in main.dart (AudioService.init must
/// run before runApp) and injected here via ProviderScope overrides, so
/// every screen shares the same background-playback session.
final audioHandlerProvider = Provider<AudioPlayerHandler>((ref) {
  throw UnimplementedError(
    'audioHandlerProvider must be overridden in main.dart after AudioService.init()',
  );
});
