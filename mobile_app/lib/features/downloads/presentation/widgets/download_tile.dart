import 'package:flutter/material.dart';

import '../../../../app/theme/app_theme.dart';
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              width: 80,
              height: 48,
              child: task.thumbnailUrl != null
                  ? Image.network(
                      task.thumbnailUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) =>
                          const ColoredBox(color: Colors.white12),
                    )
                  : const ColoredBox(color: Colors.white12),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  task.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text(
                  _subtitle,
                  style: TextStyle(
                    color: task.status == DownloadStatus.failed
                        ? Colors.redAccent
                        : AppTheme.textSecondary,
                    fontSize: 12,
                  ),
                ),
                if (task.status == DownloadStatus.downloading ||
                    task.status == DownloadStatus.paused) ...[
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: LinearProgressIndicator(
                      value: task.progress == 0 ? null : task.progress,
                      minHeight: 3,
                      backgroundColor: Colors.white12,
                      valueColor:
                          const AlwaysStoppedAnimation(AppTheme.accent),
                    ),
                  ),
                ],
              ],
            ),
          ),
          _buildAction(),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: AppTheme.textSecondary),
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
          icon: const Icon(Icons.play_circle_fill, color: AppTheme.accent),
          onPressed: onPlay,
        );
      case DownloadStatus.downloading:
      case DownloadStatus.queued:
        return IconButton(
          icon: const Icon(Icons.pause_circle_outline),
          onPressed: onPrimaryAction,
        );
      case DownloadStatus.paused:
        return IconButton(
          icon: const Icon(Icons.play_circle_outline),
          onPressed: onPrimaryAction,
        );
      case DownloadStatus.failed:
        return IconButton(
          icon: const Icon(Icons.refresh, color: Colors.redAccent),
          onPressed: onPrimaryAction,
        );
      case DownloadStatus.revoked:
        return const SizedBox(width: 48);
    }
  }
}
