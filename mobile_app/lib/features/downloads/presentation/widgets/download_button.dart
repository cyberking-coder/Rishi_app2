import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_theme.dart';
import '../../application/download_providers.dart';
import '../../domain/entities/download_content_type.dart';
import '../../domain/entities/download_status.dart';

/// Drop-in control for any content detail screen: starts a download, shows
/// live progress as a ring, and toggles pause/resume. Tapping a completed
/// download offers removal.
///
/// [size] and [color] exist because this button has to sit next to other
/// icons and look like one of them. It used to be an IconButton with no
/// colour, which inherited the app's IconTheme — near-black text meant for
/// a cream background. On the now-playing screen, which is a deep sage
/// #1B2723, that came out at a contrast ratio of 1.17:1 and was for
/// practical purposes invisible. Callers on a dark surface must pass a
/// colour; there is no sensible default that works on both.
class DownloadButton extends ConsumerWidget {
  final String contentId;
  final DownloadContentType contentType;
  final String title;
  final String? thumbnailUrl;

  /// Glyph size in logical pixels. Match whatever the icons beside it use.
  final double size;

  /// Colour for the idle and in-progress states. Null inherits the
  /// ambient IconTheme, which is only right on a light surface.
  final Color? color;

  const DownloadButton({
    super.key,
    required this.contentId,
    required this.contentType,
    required this.title,
    this.thumbnailUrl,
    this.size = 24,
    this.color,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final task = ref.watch(downloadForContentProvider(contentId));
    final repo = ref.read(downloadRepositoryProvider);
    final base = color ?? IconTheme.of(context).color;

    if (task == null) {
      return _IconTap(
        tooltip: 'Download',
        icon: Icons.download_outlined,
        size: size,
        color: base,
        onTap: () async {
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
        // sageLight, not sage. The darker sage is legible on cream and
        // sinks into the now-playing background; this one clears 6.7:1
        // on that surface and still reads as "done" on a light one.
        return _IconTap(
          tooltip: 'Downloaded — tap to remove',
          icon: Icons.download_done,
          size: size,
          color: AppTheme.sageLight,
          onTap: () => _confirmDelete(context, () => repo.delete(task.id)),
        );

      case DownloadStatus.downloading:
      case DownloadStatus.queued:
        return _ProgressRing(
          progress: task.progress,
          icon: Icons.pause,
          size: size,
          color: base,
          onTap: () => repo.pause(task.id),
        );

      case DownloadStatus.paused:
        return _ProgressRing(
          progress: task.progress,
          icon: Icons.download,
          size: size,
          color: base,
          onTap: () => repo.resume(task.id),
        );

      case DownloadStatus.failed:
        return _IconTap(
          tooltip: task.errorMessage ?? 'Download failed — retry',
          icon: Icons.error_outline,
          size: size,
          color: Colors.redAccent,
          onTap: () => repo.resume(task.id),
        );

      case DownloadStatus.revoked:
        return _IconTap(
          tooltip: 'No longer available offline',
          icon: Icons.block,
          size: size,
          color: AppTheme.textSecondary,
          onTap: null,
        );
    }
  }

  void _confirmDelete(BuildContext context, VoidCallback onConfirm) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceCream,
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

/// An icon drawn at exactly [size], with a tap area padded out around it.
///
/// Not an IconButton. IconButton pads a 24px glyph out to a ~40px box, so
/// dropping one beside plain `Icon(size: 26)` siblings and constraining it
/// to match shrank the glyph to about 15px — the button looked both faint
/// and smaller than everything next to it. Here the glyph is the size it
/// is asked for and the padding is hit-test-only, so the row still aligns.
class _IconTap extends StatelessWidget {
  final IconData icon;
  final double size;
  final Color? color;
  final String? tooltip;
  final VoidCallback? onTap;

  const _IconTap({
    required this.icon,
    required this.size,
    required this.color,
    this.tooltip,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final child = GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Icon(icon, size: size, color: color),
    );
    return tooltip == null ? child : Tooltip(message: tooltip!, child: child);
  }
}

class _ProgressRing extends StatelessWidget {
  final double progress;
  final IconData icon;
  final double size;
  final Color? color;
  final VoidCallback onTap;

  const _ProgressRing({
    required this.progress,
    required this.icon,
    required this.size,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: size,
        height: size,
        child: Stack(
          alignment: Alignment.center,
          children: [
            SizedBox.expand(
              child: CircularProgressIndicator(
                value: progress == 0 ? null : progress,
                strokeWidth: 2.5,
                // Black at 12% is invisible on a dark surface — it was
                // chosen when every screen was cream. The unfilled track
                // now derives from the icon colour instead.
                backgroundColor: (color ?? AppTheme.sage).withValues(alpha: 0.24),
                valueColor: AlwaysStoppedAnimation(color ?? AppTheme.sage),
              ),
            ),
            Icon(icon, size: size * 0.55, color: color),
          ],
        ),
      ),
    );
  }
}
