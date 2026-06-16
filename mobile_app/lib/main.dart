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

  runApp(
    ProviderScope(
      overrides: [audioHandlerProvider.overrideWithValue(audioHandler)],
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
