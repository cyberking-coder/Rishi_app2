import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app/router/app_router.dart';
import 'app/theme/app_theme.dart';
import 'core/config/app_config.dart';
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

  // Surface any uncaught Flutter error instead of a blank black screen.
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    debugPrint('FlutterError: ${details.exceptionAsString()}');
  };

  await Supabase.initialize(
    url: AppConfig.supabaseUrl,
    anonKey: AppConfig.supabaseAnonKey,
  );

  final audioRepository =
      AudioRepositoryImpl(AudioRemoteDataSource(Supabase.instance.client));

  // Audio + downloads are optional at boot. If either fails to initialise
  // (e.g. missing native channel, storage permission), the app must still
  // reach the login screen rather than dying to a black screen.
  AudioPlayerHandler? audioHandler;
  try {
    audioHandler = await AudioService.init(
      builder: () => AudioPlayerHandler(audioRepository),
      config: const AudioServiceConfig(
        androidNotificationChannelId: AppConfig.audioChannelId,
        androidNotificationChannelName: AppConfig.audioChannelName,
        androidStopForegroundOnPause: true,
      ),
    );
  } catch (e, st) {
    debugPrint('AudioService.init failed: $e\n$st');
    // Provide a plain handler so the app can still reach the login screen.
    // Background audio notification won't work but the UI will load.
    audioHandler = AudioPlayerHandler(audioRepository);
  }

  final downloadRepository = DownloadRepositoryImpl(
    storage: SecureDownloadStorage(),
    metadataStore: DownloadMetadataStore(),
    resolver: DownloadSourceResolver(Supabase.instance.client),
    proxy: LocalDecryptingProxy(),
  );
  try {
    await downloadRepository.restore();
    unawaited(downloadRepository.purgeRevokedAndExpired());
  } catch (e, st) {
    debugPrint('Download restore failed: $e\n$st');
  }

  runApp(
    ProviderScope(
      overrides: [
        audioHandlerProvider.overrideWithValue(audioHandler!),
        downloadRepositoryProvider.overrideWithValue(downloadRepository),
      ],
      child: const MeditationApp(),
    ),
  );
}

class MeditationApp extends ConsumerWidget {
  const MeditationApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(goRouterProvider);

    return MaterialApp.router(
      title: AppConfig.appName,
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.dark,
      darkTheme: AppTheme.dark(),
      theme: AppTheme.dark(),
      routerConfig: router,
    );
  }
}
