import 'package:flutter/material.dart';

import '../../application/ott_player_controller.dart';

class QualitySelectorSheet extends StatelessWidget {
  final OttPlayerController controller;

  const QualitySelectorSheet({super.key, required this.controller});

  static Future<void> show(BuildContext context, OttPlayerController controller) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1F1F1F),
      builder: (_) => QualitySelectorSheet(controller: controller),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: controller.availableQualities.map((quality) {
          final selected = quality.label == controller.currentQuality?.label;
          return ListTile(
            title: Text(quality.label, style: const TextStyle(color: Colors.white)),
            trailing: selected ? const Icon(Icons.check, color: Colors.redAccent) : null,
            onTap: () {
              controller.switchQuality(quality);
              Navigator.of(context).pop();
            },
          );
        }).toList(),
      ),
    );
  }
}
