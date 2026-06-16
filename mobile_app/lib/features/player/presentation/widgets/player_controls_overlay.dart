import 'package:flutter/material.dart';

import '../../application/ott_player_controller.dart';
import 'quality_selector_sheet.dart';
import 'speed_selector_sheet.dart';

class PlayerControlsOverlay extends StatelessWidget {
  final OttPlayerController controller;
  final bool visible;
  final VoidCallback onTapBackground;

  const PlayerControlsOverlay({
    super.key,
    required this.controller,
    required this.visible,
    required this.onTapBackground,
  });

  String _formatDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: visible ? 1 : 0,
      duration: const Duration(milliseconds: 200),
      child: IgnorePointer(
        ignoring: !visible,
        child: GestureDetector(
          onTap: onTapBackground,
          child: Container(
            color: Colors.black.withOpacity(0.35),
            child: Column(
              children: [
                _topBar(context),
                const Spacer(),
                _centerPlayPause(),
                const Spacer(),
                _bottomBar(context),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _topBar(BuildContext context) {
    return SafeArea(
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.speed, color: Colors.white),
            onPressed: () => SpeedSelectorSheet.show(context, controller),
          ),
          if (controller.availableQualities.length > 1)
            IconButton(
              icon: const Icon(Icons.hd_outlined, color: Colors.white),
              onPressed: () => QualitySelectorSheet.show(context, controller),
            ),
        ],
      ),
    );
  }

  Widget _centerPlayPause() {
    return IconButton(
      iconSize: 56,
      icon: Icon(
        controller.isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled,
        color: Colors.white,
      ),
      onPressed: controller.togglePlayPause,
    );
  }

  Widget _bottomBar(BuildContext context) {
    final position = controller.position;
    final duration = controller.duration;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: Row(
          children: [
            Text(_formatDuration(position), style: const TextStyle(color: Colors.white)),
            Expanded(
              child: SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  activeTrackColor: const Color(0xFFE50914),
                  thumbColor: const Color(0xFFE50914),
                  inactiveTrackColor: Colors.white24,
                  trackHeight: 3,
                ),
                child: Slider(
                  min: 0,
                  max: duration.inMilliseconds.toDouble().clamp(1, double.infinity),
                  value: position.inMilliseconds
                      .toDouble()
                      .clamp(0, duration.inMilliseconds.toDouble().clamp(1, double.infinity)),
                  onChanged: (value) {
                    controller.seekTo(Duration(milliseconds: value.toInt()));
                  },
                ),
              ),
            ),
            Text(_formatDuration(duration), style: const TextStyle(color: Colors.white)),
            IconButton(
              icon: Icon(
                controller.isFullscreen ? Icons.fullscreen_exit : Icons.fullscreen,
                color: Colors.white,
              ),
              onPressed: controller.toggleFullscreen,
            ),
          ],
        ),
      ),
    );
  }
}
