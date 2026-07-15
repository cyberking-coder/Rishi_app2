import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../application/download_providers.dart';
import '../../domain/entities/download_status.dart';
import '../widgets/download_tile.dart';

const _kBg = Color(0xFF12082E);
const _kAccent = Color(0xFF8B5CF6);
const _kSub = Color(0xFFB0A8CC);

/// Lists every offline download with its live status, and routes completed
/// items to the encrypted offline player.
class DownloadsScreen extends ConsumerStatefulWidget {
  const DownloadsScreen({super.key});

  @override
  ConsumerState<DownloadsScreen> createState() => _DownloadsScreenState();
}

class _DownloadsScreenState extends ConsumerState<DownloadsScreen> {
  // Guards against rapid double-taps spawning multiple player screens.
  bool _navigating = false;

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tasksAsync = ref.watch(downloadTasksProvider);
    final repo = ref.read(downloadRepositoryProvider);

    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        backgroundColor: _kBg,
        title: const Text('Downloads', style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: tasksAsync.when(
        loading: () =>
            const Center(child: CircularProgressIndicator(color: _kAccent)),
        error: (e, _) => const Center(
          child: Text('Could not load downloads',
              style: TextStyle(color: _kSub)),
        ),
        data: (tasks) {
          if (tasks.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text(
                  'No downloads yet.\nTap the download icon on a title to save it for offline viewing.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: _kSub),
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
                onDelete: () async {
                  try {
                    await repo.delete(task.id);
                  } catch (e) {
                    _showError('Could not delete download');
                  }
                },
                onPrimaryAction: () async {
                  try {
                    switch (task.status) {
                      case DownloadStatus.downloading:
                      case DownloadStatus.queued:
                        await repo.pause(task.id);
                      case DownloadStatus.paused:
                      case DownloadStatus.failed:
                        await repo.resume(task.id);
                      default:
                        break;
                    }
                  } catch (e) {
                    _showError('Action failed. Please try again.');
                  }
                },
                onPlay: () async {
                  if (_navigating) return;
                  setState(() => _navigating = true);
                  await context.push(
                    '/offline-player/${task.contentId}',
                    extra: task.title,
                  );
                  if (mounted) setState(() => _navigating = false);
                },
              );
            },
          );
        },
      ),
    );
  }
}
