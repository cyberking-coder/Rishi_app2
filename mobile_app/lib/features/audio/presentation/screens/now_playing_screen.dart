import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/widgets/lotus_logo.dart';
import '../../../downloads/domain/entities/download_content_type.dart';
import '../../../downloads/presentation/widgets/download_button.dart';
import '../../application/audio_providers.dart';
import '../widgets/sleep_timer_sheet.dart';
import '../widgets/speed_selector_sheet.dart';

// ── Design constants ──────────────────────────────────────────────────────────
const _kBg = Color(0xFF12082E);
const _kSurface = Color(0xFF1E1040);
const _kRing1 = Color(0xFFEC4899); // pink outer ring
const _kRing2 = Color(0xFF8B5CF6); // violet inner ring
const _kAccent = Color(0xFF9B6EFF); // buttons / active
const _kTextPrimary = Colors.white;
const _kTextSecondary = Color(0xFFB0A8CC);

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
      backgroundColor: _kBg,
      body: StreamBuilder<MediaItem?>(
        stream: handler.mediaItem,
        builder: (context, snap) {
          final media = snap.data;
          if (media == null) {
            return const Center(
              child: Text('Nothing playing',
                  style: TextStyle(color: _kTextSecondary)),
            );
          }
          return _PlayerBody(handler: handler, media: media, fmt: _fmt);
        },
      ),
    );
  }
}

class _PlayerBody extends StatelessWidget {
  final dynamic handler;
  final MediaItem media;
  final String Function(Duration) fmt;

  const _PlayerBody(
      {required this.handler, required this.media, required this.fmt});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          // ── Top bar ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back_ios,
                      color: _kTextPrimary, size: 20),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                const Expanded(
                  child: Text('Playing Now',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: _kTextPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w600)),
                ),
                IconButton(
                  icon: const Icon(Icons.more_horiz,
                      color: _kTextPrimary, size: 24),
                  onPressed: () =>
                      AudioSpeedSelectorSheet.show(context, handler),
                ),
              ],
            ),
          ),

          const Spacer(flex: 2),

          // ── Album art in glowing ring ──
          _AlbumArt(artUri: media.artUri),

          const Spacer(flex: 2),

          // ── Title + artist ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(children: [
              Text(
                media.title,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    color: _kTextPrimary,
                    fontSize: 22,
                    fontWeight: FontWeight.w800),
              ),
              if (media.artist != null) ...[
                const SizedBox(height: 6),
                Text(
                  media.artist!,
                  style: const TextStyle(
                      color: _kTextSecondary, fontSize: 14),
                ),
              ],
            ]),
          ),

          const SizedBox(height: 28),

          // ── Seek bar ──
          _SeekBar(handler: handler, media: media, fmt: fmt),

          const SizedBox(height: 20),

          // ── Transport controls ──
          _Transport(handler: handler),

          const SizedBox(height: 28),

          // ── Bottom tool row ──
          _ToolRow(handler: handler, media: media),

          const Spacer(flex: 1),
        ],
      ),
    );
  }
}

// ── Glowing circular album art ───────────────────────────────────────────────
class _AlbumArt extends StatelessWidget {
  final Uri? artUri;
  const _AlbumArt({required this.artUri});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size.width * 0.64;
    return Center(
      child: Container(
        width: size + 20,
        height: size + 20,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: _kRing2.withValues(alpha: 0.50),
              blurRadius: 60,
              spreadRadius: 12,
            ),
          ],
          gradient: const SweepGradient(
            colors: [_kRing1, _kRing2, _kRing1],
          ),
        ),
        padding: const EdgeInsets.all(4),
        child: ClipOval(
          child: SizedBox(
            width: size,
            height: size,
            child: artUri != null
                ? Image.network(artUri.toString(), fit: BoxFit.cover)
                : Container(
                    color: const Color(0xFF1E1445),
                    child: const Center(
                      child: LotusLogo(size: 72, color: Color(0xFF9B6EFF)),
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

// ── Seek / progress bar ──────────────────────────────────────────────────────
class _SeekBar extends StatelessWidget {
  final dynamic handler;
  final MediaItem media;
  final String Function(Duration) fmt;

  const _SeekBar(
      {required this.handler, required this.media, required this.fmt});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Duration?>(
      stream: handler.durationStream,
      builder: (context, durSnap) {
        final duration = durSnap.data ??
            handler.currentDuration ??
            media.duration ??
            Duration.zero;
        return StreamBuilder<Duration>(
          stream: handler.positionStream,
          builder: (context, posSnap) {
            var pos = posSnap.data ?? Duration.zero;
            if (pos > duration) pos = duration;
            final maxMs = duration.inMilliseconds
                .toDouble()
                .clamp(1.0, double.infinity)
                .toDouble();

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(children: [
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 3,
                    activeTrackColor: _kAccent,
                    inactiveTrackColor: Colors.white12,
                    thumbColor: _kAccent,
                    thumbShape:
                        const RoundSliderThumbShape(enabledThumbRadius: 6),
                    overlayShape:
                        const RoundSliderOverlayShape(overlayRadius: 14),
                  ),
                  child: Slider(
                    min: 0,
                    max: maxMs,
                    value: (pos.inMilliseconds.toDouble())
                        .clamp(0.0, maxMs) as double,
                    onChanged: (v) =>
                        handler.seek(Duration(milliseconds: v.toInt())),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(fmt(pos),
                          style: const TextStyle(
                              color: _kTextSecondary, fontSize: 12)),
                      Text(fmt(duration),
                          style: const TextStyle(
                              color: _kTextSecondary, fontSize: 12)),
                    ],
                  ),
                ),
              ]),
            );
          },
        );
      },
    );
  }
}

// ── Transport row: repeat / prev / play-pause / next / shuffle ───────────────
class _Transport extends StatefulWidget {
  final dynamic handler;
  const _Transport({required this.handler});

  @override
  State<_Transport> createState() => _TransportState();
}

class _TransportState extends State<_Transport> {
  bool _shuffle = false;
  bool _repeat = false;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<PlaybackState>(
      stream: widget.handler.playbackState,
      builder: (context, snap) {
        final playing = snap.data?.playing ?? false;

        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Repeat
            IconButton(
              icon: Icon(Icons.repeat,
                  color: _repeat ? _kAccent : _kTextSecondary, size: 24),
              onPressed: () => setState(() => _repeat = !_repeat),
            ),
            const SizedBox(width: 8),
            // Prev
            IconButton(
              icon: const Icon(Icons.skip_previous,
                  color: _kTextPrimary, size: 32),
              onPressed: widget.handler.skipToPrevious,
            ),
            const SizedBox(width: 8),
            // Play / Pause — large violet circle
            GestureDetector(
              onTap: playing ? widget.handler.pause : widget.handler.play,
              child: Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _kAccent,
                  boxShadow: [
                    BoxShadow(
                      color: _kAccent.withValues(alpha: 0.45),
                      blurRadius: 24,
                      spreadRadius: 4,
                    ),
                  ],
                ),
                child: Icon(
                  playing ? Icons.pause : Icons.play_arrow,
                  color: Colors.white,
                  size: 34,
                ),
              ),
            ),
            const SizedBox(width: 8),
            // Next
            IconButton(
              icon: const Icon(Icons.skip_next,
                  color: _kTextPrimary, size: 32),
              onPressed: widget.handler.skipToNext,
            ),
            const SizedBox(width: 8),
            // Shuffle
            IconButton(
              icon: Icon(Icons.shuffle,
                  color: _shuffle ? _kAccent : _kTextSecondary, size: 24),
              onPressed: () => setState(() => _shuffle = !_shuffle),
            ),
          ],
        );
      },
    );
  }
}

// ── Bottom tool row: Favorite / Download / Timer / More ──────────────────────
class _ToolRow extends StatefulWidget {
  final dynamic handler;
  final MediaItem media;
  const _ToolRow({required this.handler, required this.media});

  @override
  State<_ToolRow> createState() => _ToolRowState();
}

class _ToolRowState extends State<_ToolRow> {
  bool _favorite = false;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          // Favorite
          _ToolButton(
            icon: _favorite ? Icons.favorite : Icons.favorite_border,
            label: 'Favorite',
            color: _favorite ? Colors.pinkAccent : _kTextSecondary,
            onTap: () => setState(() => _favorite = !_favorite),
          ),
          // Download — reuses existing DownloadButton widget, wrapped to match style
          _DownloadTool(
            contentId: widget.media.id,
            title: widget.media.title,
            thumbnailUrl: widget.media.artUri?.toString(),
          ),
          // Timer
          _ToolButton(
            icon: Icons.timer_outlined,
            label: 'Timer',
            onTap: () => SleepTimerSheet.show(context, widget.handler),
            trailing: ValueListenableBuilder<Duration?>(
              valueListenable: widget.handler.sleepTimerRemaining,
              builder: (context, remaining, _) {
                if (remaining == null) return const SizedBox.shrink();
                final m = remaining.inMinutes.remainder(60)
                    .toString()
                    .padLeft(2, '0');
                final s = remaining.inSeconds.remainder(60)
                    .toString()
                    .padLeft(2, '0');
                return Text('$m:$s',
                    style: const TextStyle(
                        color: _kAccent, fontSize: 9));
              },
            ),
          ),
          // More / speed
          _ToolButton(
            icon: Icons.more_horiz,
            label: 'More',
            onTap: () =>
                AudioSpeedSelectorSheet.show(context, widget.handler),
          ),
        ],
      ),
    );
  }
}

class _ToolButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;
  final Widget? trailing;

  const _ToolButton({
    required this.icon,
    required this.label,
    this.color = _kTextSecondary,
    this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 26),
          const SizedBox(height: 4),
          Text(label,
              style: const TextStyle(color: _kTextSecondary, fontSize: 11)),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

class _DownloadTool extends ConsumerWidget {
  final String contentId;
  final String title;
  final String? thumbnailUrl;

  const _DownloadTool(
      {required this.contentId,
      required this.title,
      this.thumbnailUrl});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Wrap the existing DownloadButton in a column to match the tool-row style.
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 26,
          height: 26,
          child: FittedBox(
            child: DownloadButton(
              contentId: contentId,
              contentType: DownloadContentType.audio,
              title: title,
              thumbnailUrl: thumbnailUrl,
            ),
          ),
        ),
        const SizedBox(height: 4),
        const Text('Download',
            style: TextStyle(color: _kTextSecondary, fontSize: 11)),
      ],
    );
  }
}
