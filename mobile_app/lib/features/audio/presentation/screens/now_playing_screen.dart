import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_theme.dart';
import '../../application/audio_providers.dart';
import '../widgets/sleep_timer_sheet.dart';
import '../widgets/speed_selector_sheet.dart';

class NowPlayingScreen extends ConsumerWidget {
  const NowPlayingScreen({super.key});

  String _formatDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final handler = ref.watch(audioHandlerProvider);

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        actions: [
          IconButton(
            icon: const Icon(Icons.bedtime_outlined),
            onPressed: () => SleepTimerSheet.show(context, handler),
          ),
          IconButton(
            icon: const Icon(Icons.speed),
            onPressed: () => AudioSpeedSelectorSheet.show(context, handler),
          ),
        ],
      ),
      body: StreamBuilder<MediaItem?>(
        stream: handler.mediaItem,
        builder: (context, mediaItemSnapshot) {
          final mediaItem = mediaItemSnapshot.data;
          if (mediaItem == null) {
            return const Center(
              child: Text('Nothing playing', style: TextStyle(color: AppTheme.textSecondary)),
            );
          }

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: SizedBox(
                    width: 260,
                    height: 260,
                    child: mediaItem.artUri != null
                        ? Image.network(mediaItem.artUri.toString(), fit: BoxFit.cover)
                        : Container(
                            color: AppTheme.surfaceElevated,
                            child: const Icon(Icons.music_note, size: 64, color: AppTheme.textSecondary),
                          ),
                  ),
                ),
                const SizedBox(height: 28),
                Text(
                  mediaItem.title,
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                  textAlign: TextAlign.center,
                ),
                if (mediaItem.artist != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    mediaItem.artist!,
                    style: const TextStyle(color: AppTheme.textSecondary),
                  ),
                ],
                const SizedBox(height: 24),
                StreamBuilder<PlaybackState>(
                  stream: handler.playbackState,
                  builder: (context, stateSnapshot) {
                    final state = stateSnapshot.data;
                    final position = state?.position ?? Duration.zero;
                    final duration = mediaItem.duration ?? Duration.zero;
                    final playing = state?.playing ?? false;

                    return Column(
                      children: [
                        SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            activeTrackColor: AppTheme.accent,
                            thumbColor: AppTheme.accent,
                            inactiveTrackColor: Colors.white24,
                          ),
                          child: Slider(
                            min: 0,
                            max: duration.inMilliseconds.toDouble().clamp(1, double.infinity),
                            value: position.inMilliseconds
                                .toDouble()
                                .clamp(0, duration.inMilliseconds.toDouble().clamp(1, double.infinity)),
                            onChanged: (value) =>
                                handler.seek(Duration(milliseconds: value.toInt())),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(_formatDuration(position),
                                  style: const TextStyle(color: AppTheme.textSecondary)),
                              Text(_formatDuration(duration),
                                  style: const TextStyle(color: AppTheme.textSecondary)),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            IconButton(
                              iconSize: 36,
                              icon: const Icon(Icons.skip_previous),
                              onPressed: handler.skipToPrevious,
                            ),
                            const SizedBox(width: 16),
                            IconButton(
                              iconSize: 56,
                              icon: Icon(playing
                                  ? Icons.pause_circle_filled
                                  : Icons.play_circle_filled),
                              onPressed: playing ? handler.pause : handler.play,
                            ),
                            const SizedBox(width: 16),
                            IconButton(
                              iconSize: 36,
                              icon: const Icon(Icons.skip_next),
                              onPressed: handler.skipToNext,
                            ),
                          ],
                        ),
                        ValueListenableBuilder<Duration?>(
                          valueListenable: handler.sleepTimerRemaining,
                          builder: (context, remaining, _) {
                            if (remaining == null) return const SizedBox.shrink();
                            return Padding(
                              padding: const EdgeInsets.only(top: 12),
                              child: Text(
                                'Sleep timer: ${_formatDuration(remaining)} left',
                                style: const TextStyle(color: AppTheme.textSecondary),
                              ),
                            );
                          },
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
