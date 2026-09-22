import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
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

  // Crash reporting first, so anything that fails after this — including the
  // launch-time init below — is captured and shows up in Firebase Crashlytics
  // and Play's crash reports. Guarded: a device with no Play Services / no
  // google-services.json must still reach the login screen, so a failure here
  // only costs reporting, not the app. Firebase.initializeApp is idempotent,
  // so PushService.init() reusing it below is fine.
  try {
    await Firebase.initializeApp();
    FlutterError.onError = (details) {
      FlutterError.presentError(details);
      FirebaseCrashlytics.instance.recordFlutterFatalError(details);
    };
    // Uncaught async (non-Flutter) errors — e.g. a failed Future during
    // startup — which FlutterError.onError does not see.
    WidgetsBinding.instance.platformDispatcher.onError = (error, stack) {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
      return true;
    };
  } catch (e) {
    // No crash reporting on this device; still surface errors to the log
    // rather than a blank black screen.
    FlutterError.onError = (details) {
      FlutterError.presentError(details);
      debugPrint('FlutterError: ${details.exceptionAsString()}');
    };
    debugPrint('Crashlytics init skipped: $e');
  }

  await Supabase.initialize(
    url: AppConfig.supabaseUrl,
    anonKey: AppConfig.supabaseAnonKey,
  );

  // Push is optional at boot for the same reason audio and downloads are:
  // it can fail (no google-services.json, no Play Services) and the app
  // must still reach the login screen. PushService.init swallows its own
  // failures and reports isAvailable = false.
  await PushService.init();

  // Open the image-cache SQLite DB ONCE, serially, before audio_service can
  // touch it. audio_service loads every MediaItem's remote artUri through
  // flutter_cache_manager; a queue of tracks triggered several first-time
  // opens of the same DB at once and one lost the race with SQLITE_BUSY on
  // 'BEGIN EXCLUSIVE' — a launch crash on some devices. Doing one awaited
  // open here initialises the (singleton) cache store, so every later access
  // reuses it instead of racing a first open. Guarded: a failure here must
  // not itself stop the app from reaching login.
  try {
    await DefaultCacheManager().getFileFromCache('__warmup__');
  } catch (e) {
    debugPrint('Image cache warmup skipped: $e');
  }

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
