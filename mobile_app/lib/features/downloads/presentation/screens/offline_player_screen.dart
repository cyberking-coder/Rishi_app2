import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';

import '../../../../app/widgets/remote_image.dart';
import '../../../audio/application/audio_providers.dart';
import '../../application/download_providers.dart';

const _kBg = Color(0xFF1B2723);
const _kAccent = Color(0xFF8FB3A6);
const _kSub = Color(0xFFA8BBB2);

/// Plays a fully-downloaded, encrypted audio file entirely offline.
/// Bytes are decrypted on the fly by the loopback proxy so no plaintext
/// file is ever written to disk and playback works with no network.
class OfflinePlayerScreen extends ConsumerStatefulWidget {
  final String contentId;
  final String title;

  const OfflinePlayerScreen({
    super.key,
    required this.contentId,
    required this.title,
  });

  @override
  ConsumerState<OfflinePlayerScreen> createState() =>
      _OfflinePlayerScreenState();
}

class _OfflinePlayerScreenState extends ConsumerState<OfflinePlayerScreen> {
  AudioPlayer? _player;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      // Stop the global streaming handler so online + offline audio don't
      // play over each other.
      await ref.read(audioHandlerProvider).stop();

      final repo = ref.read(downloadRepositoryProvider);
      final url = await repo.localPlaybackUrl(widget.contentId);
      final player = AudioPlayer();
      await player.setUrl(url.toString());
      if (!mounted) {
        await player.dispose();
        return;
      }
      setState(() {
        _player = player;
        _loading = false;
      });
      // Do NOT await: just_audio's play() Future only completes when the
      // track *ends*, which would otherwise leave the screen "loading".
      unawaited(player.play());
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  @override
  void dispose() {
    _player?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final player = _player;

    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        backgroundColor: _kBg,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(widget.title, style: const TextStyle(color: Colors.white)),
      ),
      body: Center(
        child: _error != null
            ? Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Cannot play offline file.\n$_error',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: _kSub),
                ),
              )
            : _loading || player == null
                ? const CircularProgressIndicator(color: _kAccent)
                : _AudioControls(
                    player: player,
                    title: widget.title,
                    // The route carries only a content id and a title, so
                    // the artwork is looked up from the download itself —
                    // the same thumbnail the Downloads list already shows,
                    // saved when the file was queued. Nothing is fetched:
                    // if the image is not in the cache this falls back,
                    // which is the right behaviour for a screen whose
                    // whole promise is that it works with no network.
                    artworkUrl: ref
                        .watch(downloadForContentProvider(widget.contentId))
                        ?.thumbnailUrl,
                  ),
      ),
    );
  }
}

/// Transport for an offline file.
///
/// Stateful for the scrubber, for the same reason the Now Playing bar is:
/// while a finger is on the thumb the slider must be driven by the finger
/// and nothing else. The previous version read its value straight off
/// positionStream and seeked on every onChanged, so the thumb fought the
/// finger and one drag fired dozens of seeks.
class _AudioControls extends StatefulWidget {
  final AudioPlayer player;
  final String title;
  final String? artworkUrl;

  const _AudioControls({
    required this.player,
    required this.title,
    this.artworkUrl,
  });

  @override
  State<_AudioControls> createState() => _AudioControlsState();
}

class _AudioControlsState extends State<_AudioControls> {
  /// Where the finger is, in milliseconds. Non-null only during a drag.
  double? _dragMs;

  /// Where we asked the player to go, held until it lands so the thumb
  /// does not snap back to the old position for a frame on release.
  Duration? _pending;
  DateTime? _pendingExpiry;

  static const _tolerance = Duration(milliseconds: 750);
  static const _skip = Duration(seconds: 15);

  Duration _displayed(Duration streamPos) {
    if (_dragMs != null) return Duration(milliseconds: _dragMs!.toInt());

    final pending = _pending;
    if (pending != null) {
      final landed = (streamPos - pending).abs() <= _tolerance;
      final expired = DateTime.now().isAfter(_pendingExpiry!);
      if (landed || expired) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            setState(() {
              _pending = null;
              _pendingExpiry = null;
            });
          }
        });
      }
      return expired ? streamPos : pending;
    }
    return streamPos;
  }

  void _seekTo(Duration target) {
    setState(() {
      _dragMs = null;
      _pending = target;
      _pendingExpiry = DateTime.now().add(const Duration(seconds: 3));
    });
    widget.player.seek(target);
  }

  /// Back 15 seconds, floored at the start.
  void _back() {
    final target = widget.player.position - _skip;
    _seekTo(target < Duration.zero ? Duration.zero : target);
  }

  /// Forward 15 seconds, capped at the end only when the end is known.
  ///
  /// The null case is the same trap forward15() fell into on the online
  /// player: defaulting an unknown duration to zero makes every clamp
  /// true, so the button jumps to 0:00 — a forward control that rewinds.
  void _forward() {
    final target = widget.player.position + _skip;
    final dur = widget.player.duration;
    _seekTo(dur != null && target > dur ? dur : target);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // The artwork, where a generic headphones glyph used to be. A
          // downloaded track is one somebody chose deliberately, and the
          // cover is how they recognise it — the icon told them nothing
          // the title did not already say.
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: SizedBox(
              width: 240,
              height: 240,
              child: RemoteImage(
                url: widget.artworkUrl,
                fallback: const _ArtFallback(),
                fallbackWhileLoading: true,
              ),
            ),
          ),
          const SizedBox(height: 28),
          Text(
            widget.title,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 28),
          StreamBuilder<Duration?>(
            stream: widget.player.durationStream,
            builder: (context, durationSnap) {
              return StreamBuilder<Duration>(
                stream: widget.player.positionStream,
                builder: (context, posSnap) {
                  final duration =
                      durationSnap.data ?? widget.player.duration ?? Duration.zero;
                  var position = _displayed(posSnap.data ?? Duration.zero);
                  if (position > duration) position = duration;

                  // Milliseconds, not seconds. The old slider divided
                  // whole seconds by whole seconds, so on a 20-minute
                  // track the thumb could only land on 1200 positions
                  // and short tracks scrubbed in visible steps.
                  final maxMs = duration.inMilliseconds
                      .toDouble()
                      .clamp(1.0, double.infinity)
                      .toDouble();

                  return Column(
                    children: [
                      Slider(
                        activeColor: _kAccent,
                        min: 0,
                        max: maxMs,
                        // .toDouble() after the clamp: num.clamp returns
                        // num, and Slider.value wants a double.
                        value: position.inMilliseconds
                            .toDouble()
                            .clamp(0.0, maxMs)
                            .toDouble(),
                        onChangeStart: (v) => setState(() => _dragMs = v),
                        onChanged: (v) => setState(() => _dragMs = v),
                        onChangeEnd: (v) =>
                            _seekTo(Duration(milliseconds: v.toInt())),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(_fmt(position),
                              style:
                                  const TextStyle(color: _kSub, fontSize: 12)),
                          Text(_fmt(duration),
                              style:
                                  const TextStyle(color: _kSub, fontSize: 12)),
                        ],
                      ),
                    ],
                  );
                },
              );
            },
          ),
          const SizedBox(height: 12),
          StreamBuilder<PlayerState>(
            stream: widget.player.playerStateStream,
            builder: (context, snap) {
              final playing = snap.data?.playing ?? false;
              return Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _SkipButton(
                    icon: Icons.replay_10,
                    label: '15',
                    onTap: _back,
                  ),
                  const SizedBox(width: 20),
                  IconButton(
                    iconSize: 72,
                    color: Colors.white,
                    icon: Icon(playing
                        ? Icons.pause_circle_filled
                        : Icons.play_circle_filled),
                    onPressed: () =>
                        playing ? widget.player.pause() : widget.player.play(),
                  ),
                  const SizedBox(width: 20),
                  _SkipButton(
                    icon: Icons.forward_10,
                    label: '15',
                    onTap: _forward,
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  String _fmt(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }
}

/// A skip control.
///
/// Material ships replay_10/forward_10 but no fifteen, and the glyph
/// carries a baked-in "10". Rather than skip ten seconds to match an
/// icon, the number is drawn over it — fifteen is what the online player
/// uses, and two players disagreeing about how far a skip goes is worse
/// than an icon that needs a label.
class _SkipButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _SkipButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      iconSize: 40,
      color: Colors.white,
      onPressed: onTap,
      icon: Stack(
        alignment: Alignment.center,
        children: [
          Icon(icon, size: 40, color: Colors.white),
          // Covers the "10" cast into the glyph.
          Container(
            width: 17,
            height: 13,
            color: _kBg,
            alignment: Alignment.center,
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ArtFallback extends StatelessWidget {
  const _ArtFallback();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF24332E),
      child: const Center(
        child: Icon(Icons.headphones, size: 84, color: _kAccent),
      ),
    );
  }
}
