import 'package:flutter/material.dart';

import '../../application/audio_player_handler.dart';

class AudioSpeedSelectorSheet extends StatelessWidget {
  final AudioPlayerHandler handler;

  const AudioSpeedSelectorSheet({super.key, required this.handler});

  static Future<void> show(BuildContext context, AudioPlayerHandler handler) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1F1F1F),
      builder: (_) => AudioSpeedSelectorSheet(handler: handler),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: kAvailableAudioSpeeds.map((speed) {
          final selected = speed == handler.speed;
          return ListTile(
            title: Text('${speed}x', style: const TextStyle(color: Colors.white)),
            trailing:
                selected ? const Icon(Icons.check, color: Colors.redAccent) : null,
            onTap: () {
              handler.setSpeed(speed);
              Navigator.of(context).pop();
            },
          );
        }).toList(),
      ),
    );
  }
}
