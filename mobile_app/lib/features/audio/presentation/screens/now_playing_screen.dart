import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_theme.dart';
import '../../../../app/widgets/soft_background.dart';
import '../../../downloads/domain/entities/download_content_type.dart';
import '../../../downloads/presentation/widgets/download_button.dart';
import '../../application/audio_providers.dart';
import '../widgets/sleep_timer_sheet.dart';
import '../widgets/speed_selector_sheet.dart';

class NowPlayingScreen extends ConsumerWidget {
  const NowPlayingScreen({super.key});

  String _fmt(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final handler = ref.watch(audioHandlerProvider);

    return Scaffold(
      backgroundColor: AppTheme.canvas,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, size: 18),
          onPressed: () => Navigator.of(context).pop(),
        ),
        centerTitle: true,
        title: const Text('Playing Now',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        actions: [
          IconButton(
            icon: const Icon(Icons.more_horiz),
            onPressed: () => AudioSpeedSelectorSheet.show(context, handler),
          ),
        ],
      ),
      body: StreamBuilder<MediaItem?>(
        stream: handler.mediaItem,
        builder: (context, mediaSnap) {
          final mediaItem = mediaSnap.data;
          if (mediaItem == null) {
            return const Stack(children: [
              SoftBackground(),
              Center(child: Text('Nothing playing',
                  style: TextStyle(color: AppTheme.textSecondary))),
            ]);
          }

          return Stack(children: [
            const SoftBackground(),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  children: [
                    const SizedBox(height: 12),
                    // ── Glowing disc ──
                    Center(
                      child: Container(
                        width: 260,
                        height: 260,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const SweepGradient(
                            colors: [
                              Color(0xFF8B5CF6),
                              Color(0xFFEC4899),
                              Color(0xFF6366F1),
                              Color(0xFF8B5CF6),
                            ],
                            stops: [0.0, 0.35, 0.7, 1.0],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.accent.withValues(alpha: 0.55),
                              blurRadius: 52,
                              spreadRadius: 6,
                            ),
                          ],
                        ),
                        padding: const EdgeInsets.all(6),
                        child: ClipOval(
                          child: mediaItem.artUri != null
                              ? Image.network(mediaItem.artUri.toString(),
                                  fit: BoxFit.cover)
                              : Container(
                                  decoration: const BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [Color(0xFF312E81), Color(0xFF0C4A6E)],
                                    ),
                                  ),
                                  child: const Icon(Icons.self_improvement,
                                      size: 80, color: Colors.white70),
                                ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),
                    // ── Title + artist ──
                    Text(mediaItem.title,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            fontSize: 20, fontWeight: FontWeight.w700)),
                    if (mediaItem.artist != null) ...[
                      const SizedBox(height: 4),
                      Text(mediaItem.artist!,
                          style: const TextStyle(
                              color: AppTheme.textSecondary, fontSize: 14)),
                    ],
                    const SizedBox(height: 24),
                    // ── Progress ──
                    StreamBuilder<PlaybackState>(
                      stream: handler.playbackState,
                      builder: (context, stateSnap) {
                        final playing = stateSnap.data?.playing ?? false;
                        return StreamBuilder<Duration?>(
                          stream: handler.durationStream,
                          builder: (context, durSnap) {
                            final duration = durSnap.data ??
                                handler.currentDuration ??
                                mediaItem.duration ??
                                Duration.zero;
                            return StreamBuilder<Duration>(
                              stream: handler.positionStream,
                              builder: (context, posSnap) {
                                var pos = posSnap.data ?? Duration.zero;
                                if (pos > duration) pos = duration;
                                final maxMs = duration.inMilliseconds
                                    .toDouble()
                                    .clamp(1.0, double.infinity);
                                return Column(children: [
                                  // Slim progress bar
                                  SliderTheme(
                                    data: SliderTheme.of(context).copyWith(
                                      trackHeight: 4,
                                      activeTrackColor: AppTheme.accentBright,
                                      inactiveTrackColor:
                                          Colors.white.withValues(alpha: 0.12),
                                      thumbColor: AppTheme.accentBright,
                                      thumbShape: const RoundSliderThumbShape(
                                          enabledThumbRadius: 6),
                                      overlayShape: const RoundSliderOverlayShape(
                                          overlayRadius: 14),
                                    ),
                                    child: Slider(
                                      min: 0,
                                      max: maxMs,
                                      value: pos.inMilliseconds
                                          .toDouble()
                                          .clamp(0.0, maxMs),
                                      onChanged: (v) => handler
                                          .seek(Duration(milliseconds: v.toInt())),
                                    ),
                                  ),
                                  Padding(
                                    padding:
                                        const EdgeInsets.symmetric(horizontal: 8),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(_fmt(pos),
                                            style: const TextStyle(
                                                fontSize: 11,
                                                color: AppTheme.textDim)),
                                        Text(_fmt(duration),
                                            style: const TextStyle(
                                                fontSize: 11,
                                                color: AppTheme.textDim)),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 20),
                                  // ── Transport controls ──
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceEvenly,
                                    children: [
                                      // Shuffle (decorative)
                                      IconButton(
                                        icon: const Icon(Icons.shuffle,
                                            color: AppTheme.textDim, size: 22),
                                        onPressed: () {},
                                      ),
                                      // Skip previous
                                      IconButton(
                                        icon: const Icon(Icons.skip_previous,
                                            color: AppTheme.textSecondary, size: 28),
                                        onPressed: handler.skipToPrevious,
                                      ),
                                      // Play/Pause — violet circle
                                      GestureDetector(
                                        onTap: playing
                                            ? handler.pause
                                            : handler.play,
                                        child: Container(
                                          width: 62,
                                          height: 62,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            gradient: AppTheme.heroGradient,
                                            boxShadow: [
                                              BoxShadow(
                                                color: AppTheme.accent
                                                    .withValues(alpha: 0.5),
                                                blurRadius: 24,
                                                offset: const Offset(0, 8),
                                              ),
                                            ],
                                          ),
                                          child: Icon(
                                            playing
                                                ? Icons.pause
                                                : Icons.play_arrow,
                                            color: Colors.white,
                                            size: 28,
                                          ),
                                        ),
                                      ),
                                      // Skip next
                                      IconButton(
                                        icon: const Icon(Icons.skip_next,
                                            color: AppTheme.textSecondary, size: 28),
                                        onPressed: handler.skipToNext,
                                      ),
                                      // Repeat (decorative)
                                      IconButton(
                                        icon: const Icon(Icons.repeat,
                                            color: AppTheme.textDim, size: 22),
                                        onPressed: () {},
                                      ),
                                    ],
                                  ),
                                  // Sleep timer remaining
                                  ValueListenableBuilder<Duration?>(
                                    valueListenable: handler.sleepTimerRemaining,
                                    builder: (context, remaining, _) {
                                      if (remaining == null)
                                        return const SizedBox.shrink();
                                      return Padding(
                                        padding: const EdgeInsets.only(top: 8),
                                        child: Text(
                                          'Sleep timer: ${_fmt(remaining)} left',
                                          style: const TextStyle(
                                              color: AppTheme.textSecondary,
                                              fontSize: 12),
                                        ),
                                      );
                                    },
                                  ),
                                  const SizedBox(height: 28),
                                  // ── Bottom tool row ──
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceEvenly,
                                    children: [
                                      _ToolButton(
                                        icon: Icons.favorite_border,
                                        label: 'Favorite',
                                        onTap: () {},
                                      ),
                                      // Download — wraps existing DownloadButton
                                      _DownloadTool(
                                        contentId: mediaItem.id,
                                        title: mediaItem.title,
                                        thumbnailUrl:
                                            mediaItem.artUri?.toString(),
                                      ),
                                      _ToolButton(
                                        icon: Icons.bedtime_outlined,
                                        label: 'Timer',
                                        onTap: () => SleepTimerSheet.show(
                                            context, handler),
                                      ),
                                      _ToolButton(
                                        icon: Icons.more_horiz,
                                        label: 'More',
                                        onTap: () =>
                                            AudioSpeedSelectorSheet.show(
                                                context, handler),
                                      ),
                                    ],
                                  ),
                                ]);
                              },
                            );
                          },
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ]);
        },
      ),
    );
  }
}

class _ToolButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _ToolButton(
      {required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: AppTheme.textDim, size: 22),
          const SizedBox(height: 6),
          Text(label,
              style:
                  const TextStyle(fontSize: 10, color: AppTheme.textDim)),
        ],
      ),
    );
  }
}

class _DownloadTool extends StatelessWidget {
  final String contentId;
  final String title;
  final String? thumbnailUrl;
  const _DownloadTool(
      {required this.contentId, required this.title, this.thumbnailUrl});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        DownloadButton(
          contentId: contentId,
          contentType: DownloadContentType.audio,
          title: title,
          thumbnailUrl: thumbnailUrl,
        ),
        const SizedBox(height: 6),
        const Text('Download',
            style: TextStyle(fontSize: 10, color: AppTheme.textDim)),
      ],
    );
  }
}
