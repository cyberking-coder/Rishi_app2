import 'package:flutter/material.dart';

import '../../application/ott_player_controller.dart';

class SpeedSelectorSheet extends StatelessWidget {
  final OttPlayerController controller;

  const SpeedSelectorSheet({super.key, required this.controller});

  static Future<void> show(BuildContext context, OttPlayerController controller) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1F1F1F),
      builder: (_) => SpeedSelectorSheet(controller: controller),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: kAvailablePlaybackSpeeds.map((speed) {
          final selected = speed == controller.playbackSpeed;
          return ListTile(
            title: Text('${speed}x', style: const TextStyle(color: Colors.white)),
            trailing: selected ? const Icon(Icons.check, color: Colors.redAccent) : null,
            onTap: () {
              controller.setPlaybackSpeed(speed);
              Navigator.of(context).pop();
            },
          );
        }).toList(),
      ),
    );
  }
}
