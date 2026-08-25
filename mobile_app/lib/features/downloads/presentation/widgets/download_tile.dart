import 'package:flutter/material.dart';

import '../../../../app/theme/app_theme.dart';
import '../../../../app/widgets/remote_image.dart';
import '../../domain/entities/download_status.dart';
import '../../domain/entities/download_task.dart';

/// One row in the Downloads screen: thumbnail, title, status/progress, and
/// the contextual action (pause/resume/play/retry) + delete.
class DownloadTile extends StatelessWidget {
  final DownloadTask task;
  final VoidCallback onPrimaryAction;
  final VoidCallback onDelete;
  final VoidCallback? onPlay;

  const DownloadTile({
    super.key,
    required this.task,
    required this.onPrimaryAction,
    required this.onDelete,
    this.onPlay,
  });

  String get _subtitle {
    switch (task.status) {
      case DownloadStatus.downloading:
        return '${task.status.label} · ${(task.progress * 100).toStringAsFixed(0)}%'
            '${_sizeSuffix()}';
      case DownloadStatus.paused:
      case DownloadStatus.failed:
        return '${task.status.label} · ${(task.progress * 100).toStringAsFixed(0)}%';
      default:
        return task.status.label + _sizeSuffix();
    }
  }

  String _sizeSuffix() {
    final total = task.totalBytes;
    if (total == null || total == 0) return '';
    final mb = (total / (1024 * 1024)).toStringAsFixed(1);
    return ' · $mb MB';
  }

  @override
  Widget build(BuildContext context) {
    // A glass row rather than a divided list item. Downloads sit on the
    // same lavender canvas as everything else, and a plain row with a
    // hairline under it was the one place in the app still drawn like a
    // settings list.
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: AppTheme.glassSurface(),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(11),
            child: SizedBox(
              width: 96,
              height: 56,
              child: RemoteImage(
                url: task.thumbnailUrl,
                fallback: const _ThumbFallback(),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  task.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: AppTheme.text,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    letterSpacing: -0.16,
                    height: 1.3,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  _subtitle,
                  style: TextStyle(
                    fontFamily: AppTheme.text,
                    color: task.status == DownloadStatus.failed
                        ? AppTheme.danger
                        : AppTheme.textSecondary,
                    fontSize: 13,
                  ),
                ),
                if (task.status == DownloadStatus.downloading ||
                    task.status == DownloadStatus.paused) ...[
                  const SizedBox(height: 7),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: LinearProgressIndicator(
                      value: task.progress == 0 ? null : task.progress,
                      minHeight: 3,
                      backgroundColor: AppTheme.well,
                      valueColor: const AlwaysStoppedAnimation(AppTheme.sage),
                    ),
                  ),
                ],
              ],
            ),
          ),
          _buildAction(),
          IconButton(
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.delete_outline,
                size: 20, color: AppTheme.textSecondary),
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }

  Widget _buildAction() {
    switch (task.status) {
      case DownloadStatus.completed:
        return IconButton(
          visualDensity: VisualDensity.compact,
          icon: const Icon(Icons.play_circle_fill,
              size: 26, color: AppTheme.sage),
          onPressed: onPlay,
        );
      case DownloadStatus.downloading:
      case DownloadStatus.queued:
        return IconButton(
          visualDensity: VisualDensity.compact,
          icon: const Icon(Icons.pause_circle_outline,
              size: 24, color: AppTheme.sageDark),
          onPressed: onPrimaryAction,
        );
      case DownloadStatus.paused:
        return IconButton(
          visualDensity: VisualDensity.compact,
          icon: const Icon(Icons.play_circle_outline,
              size: 24, color: AppTheme.sageDark),
          onPressed: onPrimaryAction,
        );
      case DownloadStatus.failed:
        return IconButton(
          visualDensity: VisualDensity.compact,
          icon: const Icon(Icons.refresh, size: 22, color: AppTheme.danger),
          onPressed: onPrimaryAction,
        );
      case DownloadStatus.revoked:
        // No action, but the row still reserves the width so a revoked
        // item's delete button lines up with every other one's.
        return const SizedBox(width: 40);
    }
  }
}

/// Stands in for a missing thumbnail. A violet tint rather than the
/// white12 this used to draw — that was a leftover from the dark theme
/// and rendered as an almost invisible smear on a light page.
class _ThumbFallback extends StatelessWidget {
  const _ThumbFallback();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: AppTheme.sageSoft,
      child: Icon(Icons.play_arrow_rounded,
          color: AppTheme.sageLight, size: 24),
    );
  }
}
