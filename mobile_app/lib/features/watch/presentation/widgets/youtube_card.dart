import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../app/theme/app_theme.dart';
import '../../domain/entities/youtube_video.dart';

/// Opens the video on YouTube. External by design — the app never embeds
/// or re-hosts this content, it points at it.
Future<void> openYoutube(BuildContext context, YoutubeVideo video) async {
  final uri = Uri.tryParse(video.youtubeUrl);
  if (uri == null) return;
  final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
  if (!opened && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Could not open YouTube.')),
    );
  }
}

/// Thumbnail with a play badge. Sized by its parent so the same card
/// serves the horizontal home row and the full-width Watch list.
class YoutubeThumbnail extends StatelessWidget {
  final YoutubeVideo video;

  const YoutubeThumbnail({super.key, required this.video});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppTheme.radiusCard),
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: Stack(fit: StackFit.expand, children: [
          Image.network(
            video.thumbnail,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(
              decoration: const BoxDecoration(gradient: AppTheme.sageGradient),
              child: const Center(
                child: Icon(Icons.play_circle_outline_rounded,
                    color: Colors.white54, size: 34),
              ),
            ),
          ),
          // Scrim keeps the play badge readable over a bright frame.
          Container(color: Colors.black.withValues(alpha: 0.12)),
          Center(
            child: Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.92),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.play_arrow_rounded,
                  color: Color(0xFFCC0000), size: 22),
            ),
          ),
        ]),
      ),
    );
  }
}
