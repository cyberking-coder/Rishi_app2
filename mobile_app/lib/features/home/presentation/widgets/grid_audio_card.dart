import 'package:flutter/material.dart';

import '../../domain/entities/audio_summary.dart';

/// A soft, rounded grid tile (à la modern meditation apps): a pastel gradient
/// background, the cover image when present, and the title at the bottom.
class GridAudioCard extends StatelessWidget {
  final AudioSummary audio;
  final VoidCallback onTap;

  /// Index in the list — used to cycle through the pastel palette so adjacent
  /// cards differ.
  final int index;

  const GridAudioCard({
    super.key,
    required this.audio,
    required this.onTap,
    required this.index,
  });

  // Alternating rose & teal pairs — the two signature colours of the design.
  static const List<List<Color>> _palette = [
    [Color(0xFFFAC6D5), Color(0xFFF2A0BA)], // rose
    [Color(0xFFAEE2E0), Color(0xFF74C9CA)], // teal
    [Color(0xFFFBD4DE), Color(0xFFF4AEC4)], // soft pink
    [Color(0xFFBFE8E5), Color(0xFF6FC4C6)], // aqua
  ];

  @override
  Widget build(BuildContext context) {
    final colors = _palette[index % _palette.length];
    final hasCover = audio.coverArtUrl != null && audio.coverArtUrl!.isNotEmpty;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: colors,
          ),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: colors[1].withValues(alpha: 0.45),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (hasCover)
                Image.network(
                  audio.coverArtUrl!,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                ),
              // Bottom scrim so the title is always legible.
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withValues(alpha: hasCover ? 0.45 : 0.0),
                      ],
                      stops: const [0.5, 1.0],
                    ),
                  ),
                ),
              ),
              // Play glyph, top-right.
              Positioned(
                top: 12,
                right: 12,
                child: Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.85),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.play_arrow_rounded,
                      color: Color(0xFF3F8E91), size: 22),
                ),
              ),
              // Title (and artist) bottom-left.
              Positioned(
                left: 14,
                right: 14,
                bottom: 14,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      audio.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        height: 1.2,
                        color: hasCover ? Colors.white : const Color(0xFF2C3F44),
                      ),
                    ),
                    if (audio.artist != null && audio.artist!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          audio.artist!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            color: hasCover
                                ? Colors.white.withValues(alpha: 0.85)
                                : const Color(0xFF5E7A7E),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
