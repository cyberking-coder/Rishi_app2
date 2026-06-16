import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';

import '../../application/ott_player_controller.dart';
import '../../application/player_providers.dart';
import '../widgets/player_controls_overlay.dart';

class VideoPlayerScreen extends ConsumerStatefulWidget {
  final String videoId;

  const VideoPlayerScreen({super.key, required this.videoId});

  @override
  ConsumerState<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends ConsumerState<VideoPlayerScreen> {
  bool _controlsVisible = true;
  Timer? _hideTimer;

  @override
  void initState() {
    super.initState();
    _scheduleAutoHide();
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    super.dispose();
  }

  void _scheduleAutoHide() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _controlsVisible = false);
    });
  }

  void _toggleControls() {
    setState(() => _controlsVisible = !_controlsVisible);
    if (_controlsVisible) _scheduleAutoHide();
  }

  @override
  Widget build(BuildContext context) {
    final controller = ref.watch(ottPlayerControllerProvider(widget.videoId));

    return Scaffold(
      backgroundColor: Colors.black,
      body: AnimatedBuilder(
        animation: controller,
        builder: (context, _) => _buildBody(controller),
      ),
    );
  }

  Widget _buildBody(OttPlayerController controller) {
    switch (controller.status) {
      case PlayerLoadStatus.loading:
        return const Center(
          child: CircularProgressIndicator(color: Colors.redAccent),
        );
      case PlayerLoadStatus.error:
        return Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, color: Colors.white54, size: 40),
                const SizedBox(height: 12),
                Text(
                  controller.errorMessage ?? 'Playback failed',
                  style: const TextStyle(color: Colors.white),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: controller.initialize,
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        );
      case PlayerLoadStatus.ready:
        final videoController = controller.videoController!;
        return GestureDetector(
          onTap: _toggleControls,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Center(
                child: AspectRatio(
                  aspectRatio: videoController.value.aspectRatio,
                  child: VideoPlayer(videoController),
                ),
              ),
              PlayerControlsOverlay(
                controller: controller,
                visible: _controlsVisible,
                onTapBackground: _toggleControls,
              ),
            ],
          ),
        );
    }
  }
}
