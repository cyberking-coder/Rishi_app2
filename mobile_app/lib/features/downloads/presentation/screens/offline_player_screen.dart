import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';

import '../../../../app/theme/app_theme.dart';
import '../../application/download_providers.dart';

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
      final repo = ref.read(downloadRepositoryProvider);
      final url = await repo.localPlaybackUrl(widget.contentId);
      final player = AudioPlayer();
      await player.setUrl(url.toString());
      await player.play();
      if (!mounted) {
        await player.dispose();
        return;
      }
      setState(() {
        _player = player;
        _loading = false;
      });
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
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.background,
        title: Text(widget.title),
      ),
      body: Center(
        child: _error != null
            ? Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Cannot play offline file.\n$_error',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppTheme.textSecondary),
                ),
              )
            : _loading || player == null
                ? const CircularProgressIndicator(color: AppTheme.accent)
                : _AudioControls(player: player, title: widget.title),
      ),
    );
  }
}

class _AudioControls extends StatelessWidget {
  final AudioPlayer player;
  final String title;

  const _AudioControls({required this.player, required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.headphones, size: 120, color: AppTheme.accent),
          const SizedBox(height: 32),
          Text(
            title,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          StreamBuilder<Duration?>(
            stream: player.durationStream,
            builder: (context, durationSnap) {
              return StreamBuilder<Duration>(
                stream: player.positionStream,
                builder: (context, posSnap) {
                  final duration = durationSnap.data ?? Duration.zero;
                  final position = posSnap.data ?? Duration.zero;
                  return Column(
                    children: [
                      Slider(
                        activeColor: AppTheme.accent,
                        value: duration.inSeconds == 0
                            ? 0
                            : (position.inSeconds / duration.inSeconds).clamp(0.0, 1.0),
                        onChanged: (v) => player.seek(
                          Duration(seconds: (v * duration.inSeconds).round()),
                        ),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(_fmt(position),
                              style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                          Text(_fmt(duration),
                              style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                        ],
                      ),
                    ],
                  );
                },
              );
            },
          ),
          const SizedBox(height: 16),
          StreamBuilder<PlayerState>(
            stream: player.playerStateStream,
            builder: (context, snap) {
              final playing = snap.data?.playing ?? false;
              return IconButton(
                iconSize: 72,
                color: Colors.white,
                icon: Icon(playing ? Icons.pause_circle_filled : Icons.play_circle_filled),
                onPressed: () => playing ? player.pause() : player.play(),
              );
            },
          ),
        ],
      ),
    );
  }

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}
