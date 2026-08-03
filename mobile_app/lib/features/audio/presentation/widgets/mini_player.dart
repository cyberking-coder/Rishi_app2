import 'dart:ui' show FontFeature;

import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_theme.dart';
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

            return StreamBuilder<Duration?>(
              // The duration comes from the PLAYER, not from the
              // MediaItem. MediaItem.duration is populated from
              // audios.duration_seconds, which is null for most rows —
              // and a null duration means the progress fraction is always
              // zero and the clock is hidden, so the bar looked absent
              // rather than broken. The player knows the real length once
              // the source is loaded. Now Playing already read it this
              // way; the mini-player didn't.
              stream: handler.durationStream,
              builder: (context, durationSnapshot) {
                final duration = durationSnapshot.data ?? mediaItem.duration;

                return StreamBuilder<Duration>(
                  // Position comes from the player's own continuous
                  // stream, NOT from PlaybackState, which only emits on
                  // play/pause/seek and left the bar frozen in between.
                  stream: handler.positionStream,
                  builder: (context, positionSnapshot) {
                    final position = positionSnapshot.data ?? Duration.zero;
                    final progress = _progressFraction(duration, position);

                    return GestureDetector(
                      onTap: () => context.push('/now-playing'),
                      child: Material(
                        color: AppTheme.sageDark,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            LinearProgressIndicator(
                              value: progress,
                              minHeight: 2,
                              backgroundColor: Colors.white24,
                              color: AppTheme.sand,
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
                                                  const ColoredBox(
                                                      color: Colors.white12),
                                            )
                                          : const ColoredBox(
                                              color: Colors.white12),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
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
                                              color: Color(0xCCFFFFFF),
                                              fontSize: 12,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                  // Elapsed / total, so the bar is readable
                                  // as a time rather than only as a
                                  // proportion.
                                  if (duration != null)
                                    Padding(
                                      padding:
                                          const EdgeInsets.only(left: 8),
                                      child: Text(
                                        '${_clock(position)} / '
                                        '${_clock(duration)}',
                                        style: const TextStyle(
                                          color: Color(0xCCFFFFFF),
                                          fontSize: 11,
                                          fontFeatures: [
                                            // Tabular digits, or the text
                                            // jiggles every second as glyph
                                            // widths change.
                                            FontFeature.tabularFigures(),
                                          ],
                                        ),
                                      ),
                                    ),
                                  IconButton(
                                    icon: Icon(
                                        playing
                                            ? Icons.pause
                                            : Icons.play_arrow,
                                        color: Colors.white),
                                    onPressed:
                                        playing ? handler.pause : handler.play,
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
          },
        );
      },
    );
  }

  double _progressFraction(Duration? duration, Duration position) {
    if (duration == null || duration.inMilliseconds == 0) return 0;
    return (position.inMilliseconds / duration.inMilliseconds).clamp(0, 1);
  }

  /// mm:ss, or h:mm:ss once a track passes an hour — a leading "00:" on
  /// an eight-minute meditation is noise.
  static String _clock(Duration d) {
    String two(int n) => n.toString().padLeft(2, '0');
    final minutes = two(d.inMinutes.remainder(60));
    final seconds = two(d.inSeconds.remainder(60));
    return d.inHours > 0
        ? '${d.inHours}:$minutes:$seconds'
        : '$minutes:$seconds';
  }
}
