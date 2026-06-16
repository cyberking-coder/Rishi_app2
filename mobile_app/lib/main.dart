import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app/router/app_router.dart';
import 'app/theme/app_theme.dart';
import 'features/audio/application/audio_player_handler.dart';
import 'features/audio/application/audio_providers.dart';
import 'features/audio/data/datasources/audio_remote_datasource.dart';
import 'features/audio/data/repositories/audio_repository_impl.dart';
import 'features/downloads/application/download_providers.dart';
import 'features/downloads/data/net/local_decrypting_proxy.dart';
import 'features/downloads/data/repositories/download_repository_impl.dart';
import 'features/downloads/data/sources/download_source_resolver.dart';
import 'features/downloads/data/storage/download_metadata_store.dart';
import 'features/downloads/data/storage/secure_download_storage.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: const String.fromEnvironment('SUPABASE_URL'),
    anonKey: const String.fromEnvironment('SUPABASE_ANON_KEY'),
  );

  final audioRepository =
      AudioRepositoryImpl(AudioRemoteDataSource(Supabase.instance.client));

  final audioHandler = await AudioService.init(
    builder: () => AudioPlayerHandler(audioRepository),
    config: const AudioServiceConfig(
      androidNotificationChannelId: 'com.ottapp.audio.channel',
      androidNotificationChannelName: 'OTT Audio Playback',
      androidStopForegroundOnPause: true,
    ),
  );

  // Offline downloads: build the engine, start the loopback decrypting
  // proxy, restore the manifest, and purge any revoked/expired files
  // before the UI can reference them.
  final downloadRepository = DownloadRepositoryImpl(
    storage: SecureDownloadStorage(),
    metadataStore: DownloadMetadataStore(),
    resolver: DownloadSourceResolver(Supabase.instance.client),
    proxy: LocalDecryptingProxy(),
  );
  await downloadRepository.restore();
  unawaited(downloadRepository.purgeRevokedAndExpired());

  runApp(
    ProviderScope(
      overrides: [
        audioHandlerProvider.overrideWithValue(audioHandler),
        downloadRepositoryProvider.overrideWithValue(downloadRepository),
      ],
      child: const OttApp(),
    ),
  );
}

class OttApp extends ConsumerWidget {
  const OttApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(goRouterProvider);

    return MaterialApp.router(
      title: 'OTT App',
      themeMode: ThemeMode.dark,
      darkTheme: AppTheme.dark(),
      theme: AppTheme.dark(),
      routerConfig: router,
    );
  }
}
