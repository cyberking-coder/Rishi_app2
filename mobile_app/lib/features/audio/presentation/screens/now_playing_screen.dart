import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/widgets/lotus_logo.dart';
import '../../../downloads/domain/entities/download_content_type.dart';
import '../../../downloads/presentation/widgets/download_button.dart';
import '../../application/audio_providers.dart';
import '../widgets/sleep_timer_sheet.dart';
import '../widgets/speed_selector_sheet.dart';
import '../../../../app/widgets/remote_image.dart';

// ── Design constants ──────────────────────────────────────────────────────────
// The player is the deep end of the violet ramp — the one screen you are
// inside rather than on, which is why it keeps its own constants instead
// of reading the light-theme tokens.
const _kBg = Color(0xFF2A1650);         // deep purple, immersive stage
const _kRing1 = Color(0xFFC4B5FD);      // pale violet outer ring
const _kRing2 = Color(0xFFA78BFA);      // mid violet inner ring
const _kAccent = Color(0xFFA78BFA);     // buttons / active
const _kTextPrimary = Colors.white;
const _kTextSecondary = Color(0xFFBCB4CC);

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

  Widget _artFallback() => Container(
        color: const Color(0xFF1E1445),
        child: const Center(
          child: LotusLogo(size: 72, color: Color(0xFF9B6EFF)),
        ),
      );

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
            child: RemoteImage(
              url: artUri?.toString(),
              fallback: _artFallback(),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Seek / progress bar ──────────────────────────────────────────────────────
/// The scrubber.
///
/// It is stateful for one reason: while a finger is on the thumb, the
/// slider must be driven by the finger and by nothing else.
///
/// The earlier version was stateless and read its value straight off
/// `positionStream`, seeking on every `onChanged`. That has two costs.
/// The thumb fights the finger — each rebuild during a drag snaps it back
/// toward wherever the player actually is — and every pointer movement
/// becomes a real seek, which over a signed remote URL means the platform
/// player discards its buffer and issues a fresh range request, dozens of
/// times per drag. Backwards was the worse direction, since a backward
/// seek leaves the retained forward buffer behind and always refetches.
///
/// So: one seek, on release.
class _SeekBar extends StatefulWidget {
  final dynamic handler;
  final MediaItem media;
  final String Function(Duration) fmt;

  const _SeekBar(
      {required this.handler, required this.media, required this.fmt});

  @override
  State<_SeekBar> createState() => _SeekBarState();
}

class _SeekBarState extends State<_SeekBar> {
  /// Where the finger is, in milliseconds. Non-null only during a drag.
  double? _dragMs;

  /// Where we asked the player to go, held after release.
  ///
  /// A seek is not instant, and the position stream keeps reporting the
  /// OLD position until it lands. Without this the thumb would jump back
  /// to where the track was for a beat and then forward again — the
  /// snap-back the drag state was meant to remove, reappearing at the
  /// moment of release. We keep showing the target until the player
  /// reports a position near it, or until [_pendingExpiry] passes so a
  /// seek that never lands (a dead network, a stall) cannot freeze the
  /// bar permanently.
  Duration? _pending;
  DateTime? _pendingExpiry;

  /// How close the reported position must get before we trust it again.
  /// Generous, because the platform player settles a seek at the nearest
  /// decodable frame rather than the exact millisecond asked for.
  static const _tolerance = Duration(milliseconds: 750);

  void _onChangeStart(double v) => setState(() => _dragMs = v);

  void _onChanged(double v) => setState(() => _dragMs = v);

  void _onChangeEnd(double v) {
    final target = Duration(milliseconds: v.toInt());
    setState(() {
      _dragMs = null;
      _pending = target;
      _pendingExpiry = DateTime.now().add(const Duration(seconds: 3));
    });
    widget.handler.seek(target);
  }

  /// The position to draw: the finger if one is down, then an unlanded
  /// seek target, then the player itself.
  Duration _displayed(Duration streamPos) {
    if (_dragMs != null) {
      return Duration(milliseconds: _dragMs!.toInt());
    }

    final pending = _pending;
    if (pending != null) {
      final landed = (streamPos - pending).abs() <= _tolerance;
      final expired = DateTime.now().isAfter(_pendingExpiry!);
      if (landed || expired) {
        // Clearing state inside build would be a rebuild-during-build, so
        // defer it by a frame. Until then we keep drawing the target,
        // which is what the next frame will show anyway.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) setState(() {
            _pending = null;
            _pendingExpiry = null;
          });
        });
      }
      return expired ? streamPos : pending;
    }

    return streamPos;
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Duration?>(
      stream: widget.handler.durationStream,
      builder: (context, durSnap) {
        final duration = durSnap.data ??
            widget.handler.currentDuration ??
            widget.media.duration ??
            Duration.zero;
        return StreamBuilder<Duration>(
          stream: widget.handler.positionStream,
          builder: (context, posSnap) {
            var pos = _displayed(posSnap.data ?? Duration.zero);
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
                    onChangeStart: _onChangeStart,
                    onChanged: _onChanged,
                    onChangeEnd: _onChangeEnd,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Reads the dragged time, not the playing time, so
                      // the number under the thumb tells you where you
                      // are about to land.
                      Text(widget.fmt(pos),
                          style: const TextStyle(
                              color: _kTextSecondary, fontSize: 12)),
                      Text(widget.fmt(duration),
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
  late bool _repeat = widget.handler.isLooping as bool;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<PlaybackState>(
      stream: widget.handler.playbackState,
      builder: (context, snap) {
        final playing = snap.data?.playing ?? false;

        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Repeat (loops the current track — genuinely functional)
            IconButton(
              tooltip: 'Repeat',
              icon: Icon(Icons.repeat,
                  color: _repeat ? _kAccent : _kTextSecondary, size: 24),
              onPressed: () async {
                final on = await widget.handler.toggleLoop() as bool;
                if (mounted) setState(() => _repeat = on);
              },
            ),
            const SizedBox(width: 8),
            // Rewind 15s
            IconButton(
              tooltip: 'Back 15 seconds',
              icon: const Icon(Icons.replay_10, color: _kTextPrimary, size: 32),
              onPressed: () => widget.handler.rewind15(),
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
            // Forward 15s
            IconButton(
              tooltip: 'Forward 15 seconds',
              icon: const Icon(Icons.forward_10, color: _kTextPrimary, size: 32),
              onPressed: () => widget.handler.forward15(),
            ),
            const SizedBox(width: 8),
            // Spacer to keep the play button visually centered
            const SizedBox(width: 24),
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
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
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
  final VoidCallback? onTap;
  final Widget? trailing;

  const _ToolButton({
    required this.icon,
    required this.label,
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
          Icon(icon, color: _kTextSecondary, size: 26),
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
    // Sized and coloured to match _ToolButton exactly, rather than scaled
    // to fit. The old FittedBox squeezed a padded IconButton into 26px,
    // which shrank the glyph itself to roughly 15px next to 26px
    // neighbours — and with no colour passed it inherited the app's
    // near-black icon theme onto this deep sage background.
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: 26,
          child: DownloadButton(
            contentId: contentId,
            contentType: DownloadContentType.audio,
            title: title,
            thumbnailUrl: thumbnailUrl,
            size: 26,
            color: _kTextSecondary,
          ),
        ),
        const SizedBox(height: 4),
        const Text('Download',
            style: TextStyle(color: _kTextSecondary, fontSize: 11)),
      ],
    );
  }
}
