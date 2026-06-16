import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../../../app/theme/app_theme.dart';
import '../../application/download_providers.dart';

/// Plays a fully-downloaded, encrypted file entirely offline. The bytes
/// are decrypted on the fly by the loopback proxy ([localPlaybackUrl]),
/// so no plaintext file is ever written to disk and playback works with no
/// network. Used for both offline video and audio (audio renders as an
/// audio-only surface).
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
  VideoPlayerController? _controller;
  String? _error;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      final repo = ref.read(downloadRepositoryProvider);
      final url = await repo.localPlaybackUrl(widget.contentId);
      final controller = VideoPlayerController.networkUrl(url);
      await controller.initialize();
      await WakelockPlus.enable();
      await controller.play();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() => _controller = controller);
      controller.addListener(() {
        if (mounted) setState(() {});
      });
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  @override
  void dispose() {
    WakelockPlus.disable();
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
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
            : controller == null
                ? const CircularProgressIndicator(color: AppTheme.accent)
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      AspectRatio(
                        aspectRatio: controller.value.aspectRatio == 0
                            ? 16 / 9
                            : controller.value.aspectRatio,
                        child: VideoPlayer(controller),
                      ),
                      VideoProgressIndicator(
                        controller,
                        allowScrubbing: true,
                        colors: const VideoProgressColors(
                          playedColor: AppTheme.accent,
                        ),
                      ),
                      IconButton(
                        iconSize: 56,
                        color: Colors.white,
                        icon: Icon(controller.value.isPlaying
                            ? Icons.pause_circle_filled
                            : Icons.play_circle_filled),
                        onPressed: () => controller.value.isPlaying
                            ? controller.pause()
                            : controller.play(),
                      ),
                    ],
                  ),
      ),
    );
  }
}
