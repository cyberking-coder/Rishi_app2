import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_theme.dart';
import '../../application/download_providers.dart';
import '../../domain/entities/download_content_type.dart';
import '../../domain/entities/download_status.dart';

/// Drop-in control for any content detail screen: starts a download, shows
/// live progress as a ring, and toggles pause/resume. Tapping a completed
/// download offers removal.
class DownloadButton extends ConsumerWidget {
  final String contentId;
  final DownloadContentType contentType;
  final String title;
  final String? thumbnailUrl;

  const DownloadButton({
    super.key,
    required this.contentId,
    required this.contentType,
    required this.title,
    this.thumbnailUrl,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final task = ref.watch(downloadForContentProvider(contentId));
    final repo = ref.read(downloadRepositoryProvider);

    if (task == null) {
      return IconButton(
        tooltip: 'Download',
        icon: const Icon(Icons.download_outlined),
        onPressed: () async {
          final messenger = ScaffoldMessenger.of(context);
          try {
            await repo.enqueue(
              contentId: contentId,
              contentType: contentType,
              title: title,
              thumbnailUrl: thumbnailUrl,
            );
            messenger.showSnackBar(
              const SnackBar(content: Text('Download started')),
            );
          } catch (e) {
            messenger.showSnackBar(
              SnackBar(content: Text('Could not start download: $e')),
            );
          }
        },
      );
    }

    switch (task.status) {
      case DownloadStatus.completed:
        return IconButton(
          tooltip: 'Downloaded — tap to remove',
          icon: const Icon(Icons.download_done, color: AppTheme.accent),
          onPressed: () => _confirmDelete(context, () => repo.delete(task.id)),
        );

      case DownloadStatus.downloading:
      case DownloadStatus.queued:
        return _ProgressRing(
          progress: task.progress,
          icon: Icons.pause,
          onTap: () => repo.pause(task.id),
        );

      case DownloadStatus.paused:
        return _ProgressRing(
          progress: task.progress,
          icon: Icons.download,
          onTap: () => repo.resume(task.id),
        );

      case DownloadStatus.failed:
        return IconButton(
          tooltip: task.errorMessage ?? 'Download failed — retry',
          icon: const Icon(Icons.error_outline, color: Colors.redAccent),
          onPressed: () => repo.resume(task.id),
        );

      case DownloadStatus.revoked:
        return const IconButton(
          icon: Icon(Icons.block, color: AppTheme.textSecondary),
          onPressed: null,
        );
    }
  }

  void _confirmDelete(BuildContext context, VoidCallback onConfirm) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceElevated,
        title: const Text('Remove download?'),
        content: const Text('This deletes the offline copy from this device.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              onConfirm();
            },
            child: const Text('Remove', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
  }
}

class _ProgressRing extends StatelessWidget {
  final double progress;
  final IconData icon;
  final VoidCallback onTap;

  const _ProgressRing({
    required this.progress,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 40,
        height: 40,
        child: Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              width: 32,
              height: 32,
              child: CircularProgressIndicator(
                value: progress == 0 ? null : progress,
                strokeWidth: 2.5,
                backgroundColor: Colors.black12,
                valueColor: const AlwaysStoppedAnimation(AppTheme.accent),
              ),
            ),
            Icon(icon, size: 16),
          ],
        ),
      ),
    );
  }
}
