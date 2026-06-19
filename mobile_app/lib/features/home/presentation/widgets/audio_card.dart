import 'package:flutter/material.dart';

import '../../../../app/theme/app_theme.dart';
import '../../../../core/utils/responsive.dart';
import '../../domain/entities/audio_summary.dart';

class AudioCard extends StatelessWidget {
  final AudioSummary audio;
  final VoidCallback onTap;

  const AudioCard({super.key, required this.audio, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final size = Responsive.squareCardWidth(context);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        margin: const EdgeInsets.only(right: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.textPrimary.withValues(alpha: 0.08),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: SizedBox(
                  width: size,
                  height: size,
                  child: audio.coverArtUrl != null
                      ? Image.network(
                          audio.coverArtUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const _CoverFallback(),
                        )
                      : const _CoverFallback(),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              audio.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            if (audio.artist != null)
              Text(
                audio.artist!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 12,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _CoverFallback extends StatelessWidget {
  const _CoverFallback();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppTheme.surfaceElevated,
      alignment: Alignment.center,
      child: const Icon(Icons.music_note, color: AppTheme.textSecondary),
    );
  }
}
