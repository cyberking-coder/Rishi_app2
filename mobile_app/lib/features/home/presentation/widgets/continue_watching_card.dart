import 'package:flutter/material.dart';

import '../../../../app/theme/app_theme.dart';
import '../../../../core/utils/responsive.dart';
import '../../domain/entities/continue_watching_item.dart';

class ContinueWatchingCard extends StatelessWidget {
  final ContinueWatchingItem item;
  final VoidCallback onTap;

  const ContinueWatchingCard({
    super.key,
    required this.item,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final width = Responsive.posterCardWidth(context) * 1.3;
    final height = width * 0.58;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: width,
        margin: const EdgeInsets.only(right: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: SizedBox(
                    width: width,
                    height: height,
                    child: item.thumbnailUrl != null
                        ? Image.network(item.thumbnailUrl!, fit: BoxFit.cover)
                        : Container(
                            color: AppTheme.surfaceElevated,
                            alignment: Alignment.center,
                            child: const Icon(
                              Icons.play_circle_outline,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: ClipRRect(
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(8),
                      bottomRight: Radius.circular(8),
                    ),
                    child: LinearProgressIndicator(
                      value: item.progressFraction,
                      minHeight: 4,
                      backgroundColor: Colors.white24,
                    ),
                  ),
                ),
                Positioned.fill(
                  child: Center(
                    child: Icon(
                      Icons.play_arrow,
                      size: 36,
                      color: Colors.white.withOpacity(0.85),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              item.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}
