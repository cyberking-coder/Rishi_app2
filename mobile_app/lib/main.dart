import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app/router/app_router.dart';
import 'app/theme/app_theme.dart';
import 'features/profile/application/profile_providers.dart';
import 'core/config/app_config.dart';
import 'core/push/push_service.dart';
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

  // Push is optional at boot for the same reason audio and downloads are:
  // it can fail (no google-services.json, no Play Services) and the app
  // must still reach the login screen. PushService.init swallows its own
  // failures and reports isAvailable = false.
  await PushService.init();

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
        audioHandlerProvider.overrideWithValue(audioHandler),
        downloadRepositoryProvider.overrideWithValue(downloadRepository),
      ],
      child: const MeditationApp(),
    ),
  );
}

class MeditationApp extends ConsumerStatefulWidget {
  const MeditationApp({super.key});

  @override
  ConsumerState<MeditationApp> createState() => _MeditationAppState();
}

class _MeditationAppState extends ConsumerState<MeditationApp> {
  StreamSubscription<String>? _deepLinkSubscription;

  @override
  void initState() {
    super.initState();

    // Notification taps. Two sources, one destination: a tap while the
    // app was backgrounded arrives on the stream, and a tap that launched
    // it from cold was parked in pendingDeepLink before any widget
    // existed to hear it.
    _deepLinkSubscription = PushService.deepLinks.listen(_follow);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final pending = PushService.pendingDeepLink;
      if (pending != null) {
        PushService.pendingDeepLink = null;
        _follow(pending);
      }
    });
  }

  void _follow(String link) {
    if (!mounted) return;
    // push(), not go(): the notification is a detour, and replacing the
    // stack would leave nothing behind the back button when someone
    // taps through mid-session. The router's own redirect still sends
    // them to login first if they are signed out.
    ref.read(goRouterProvider).push(link);
  }

  @override
  void dispose() {
    _deepLinkSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(goRouterProvider);
    final themeMode = ref.watch(themeModeProvider);

    // Deep links (meditationapp://app/...) are delivered straight to
    // go_router by Flutter's Router API — no separate listener needed.
    return MaterialApp.router(
      title: AppConfig.appName,
      debugShowCheckedModeBanner: false,
      themeMode: themeMode,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      routerConfig: router,
    );
  }
}
