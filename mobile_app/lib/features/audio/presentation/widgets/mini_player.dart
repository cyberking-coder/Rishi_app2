import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../application/audio_providers.dart';

/// Persistent bottom bar shown whenever a track is loaded, regardless of
/// which screen is on top -- this is what makes background playback feel
/// continuous rather than tied to a single screen.
class MiniPlayer extends ConsumerWidget {
  const MiniPlayer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final handler = ref.watch(audioHandlerProvider);

    return StreamBuilder<MediaItem?>(
      stream: handler.mediaItem,
      builder: (context, mediaItemSnapshot) {
        final mediaItem = mediaItemSnapshot.data;
        if (mediaItem == null) return const SizedBox.shrink();

        return StreamBuilder<PlaybackState>(
          stream: handler.playbackState,
          builder: (context, stateSnapshot) {
            final playing = stateSnapshot.data?.playing ?? false;
            final progress = _progressFraction(mediaItem, stateSnapshot.data);

            return GestureDetector(
              onTap: () => context.push('/now-playing'),
              child: Material(
                color: const Color(0xFF1C1040),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    LinearProgressIndicator(
                      value: progress,
                      minHeight: 2,
                      backgroundColor: Colors.white12,
                      color: const Color(0xFF8B5CF6),
                    ),
                    SizedBox(
                      height: 56,
                      child: Row(
                        children: [
                          const SizedBox(width: 10),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: SizedBox(
                              width: 40,
                              height: 40,
                              child: mediaItem.artUri != null
                                  ? Image.network(
                                      mediaItem.artUri.toString(),
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) =>
                                          const ColoredBox(color: Colors.white12),
                                    )
                                  : const ColoredBox(color: Colors.white12),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  mediaItem.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600),
                                ),
                                if (mediaItem.artist != null)
                                  Text(
                                    mediaItem.artist!,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Color(0xFFB0A8CC),
                                      fontSize: 12,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: Icon(playing ? Icons.pause : Icons.play_arrow,
                                color: Colors.white),
                            onPressed: playing ? handler.pause : handler.play,
                          ),
                          const SizedBox(width: 4),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  double _progressFraction(MediaItem mediaItem, PlaybackState? state) {
    final duration = mediaItem.duration;
    final position = state?.position;
    if (duration == null || position == null || duration.inMilliseconds == 0) {
      return 0;
    }
    return (position.inMilliseconds / duration.inMilliseconds).clamp(0, 1);
  }
}
