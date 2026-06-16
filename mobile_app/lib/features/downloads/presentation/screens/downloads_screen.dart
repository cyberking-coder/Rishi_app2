import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_theme.dart';
import '../../application/download_providers.dart';
import '../../domain/entities/download_status.dart';
import '../widgets/download_tile.dart';

/// Lists every offline download with its live status, and routes completed
/// items to the encrypted offline player.
class DownloadsScreen extends ConsumerWidget {
  const DownloadsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasksAsync = ref.watch(downloadTasksProvider);
    final repo = ref.read(downloadRepositoryProvider);

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.background,
        title: const Text('Downloads'),
      ),
      body: tasksAsync.when(
        loading: () =>
            const Center(child: CircularProgressIndicator(color: AppTheme.accent)),
        error: (e, _) => Center(
          child: Text('Could not load downloads',
              style: const TextStyle(color: AppTheme.textSecondary)),
        ),
        data: (tasks) {
          if (tasks.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text(
                  'No downloads yet.\nTap the download icon on a title to save it for offline viewing.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppTheme.textSecondary),
                ),
              ),
            );
          }

          return ListView.separated(
            itemCount: tasks.length,
            separatorBuilder: (_, __) =>
                const Divider(height: 1, color: Colors.white10),
            itemBuilder: (context, index) {
              final task = tasks[index];
              return DownloadTile(
                task: task,
                onDelete: () => repo.delete(task.id),
                onPrimaryAction: () {
                  switch (task.status) {
                    case DownloadStatus.downloading:
                    case DownloadStatus.queued:
                      repo.pause(task.id);
                    case DownloadStatus.paused:
                    case DownloadStatus.failed:
                      repo.resume(task.id);
                    default:
                      break;
                  }
                },
                onPlay: () => context.push(
                  '/offline-player/${task.contentId}',
                  extra: task.title,
                ),
              );
            },
          );
        },
      ),
    );
  }
}
