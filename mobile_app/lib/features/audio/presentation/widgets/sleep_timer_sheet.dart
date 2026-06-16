import 'package:flutter/material.dart';

import '../../application/audio_player_handler.dart';

const Map<String, Duration?> _kSleepTimerOptions = {
  'Off': null,
  '10 minutes': Duration(minutes: 10),
  '20 minutes': Duration(minutes: 20),
  '30 minutes': Duration(minutes: 30),
  '45 minutes': Duration(minutes: 45),
  '60 minutes': Duration(minutes: 60),
};

class SleepTimerSheet extends StatelessWidget {
  final AudioPlayerHandler handler;

  const SleepTimerSheet({super.key, required this.handler});

  static Future<void> show(BuildContext context, AudioPlayerHandler handler) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1F1F1F),
      builder: (_) => SleepTimerSheet(handler: handler),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text('Sleep timer', style: TextStyle(color: Colors.white, fontSize: 18)),
          ),
          ..._kSleepTimerOptions.entries.map((entry) {
            return ListTile(
              title: Text(entry.key, style: const TextStyle(color: Colors.white)),
              onTap: () {
                handler.setSleepTimer(entry.value);
                Navigator.of(context).pop();
              },
            );
          }),
        ],
      ),
    );
  }
}
