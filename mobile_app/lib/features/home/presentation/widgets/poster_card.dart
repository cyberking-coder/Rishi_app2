import 'package:flutter/material.dart';

import '../../../../app/theme/app_theme.dart';
import '../../../../core/utils/responsive.dart';
import '../../domain/entities/video_summary.dart';

/// Poster-style card for a video, with a press-scale animation so taps
/// feel responsive (Netflix-style "lift" on focus/press).
class PosterCard extends StatefulWidget {
  final VideoSummary video;
  final VoidCallback onTap;

  const PosterCard({super.key, required this.video, required this.onTap});

  @override
  State<PosterCard> createState() => _PosterCardState();
}

class _PosterCardState extends State<PosterCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final width = Responsive.posterCardWidth(context);
    final height = Responsive.posterCardHeight(context);

    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.95 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: Container(
          width: width,
          margin: const EdgeInsets.only(right: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  width: width,
                  height: height,
                  child: widget.video.thumbnailUrl != null
                      ? Image.network(
                          widget.video.thumbnailUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const _PosterFallback(),
                          loadingBuilder: (context, child, progress) {
                            if (progress == null) return child;
                            return const _PosterFallback();
                          },
                        )
                      : const _PosterFallback(),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                widget.video.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PosterFallback extends StatelessWidget {
  const _PosterFallback();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppTheme.surfaceElevated,
      alignment: Alignment.center,
      child: const Icon(Icons.movie_outlined, color: AppTheme.textSecondary),
    );
  }
}
