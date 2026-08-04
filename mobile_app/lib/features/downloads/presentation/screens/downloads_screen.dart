import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_theme.dart';
import '../../../../app/widgets/botanical.dart';
import '../../application/download_providers.dart';
import '../../domain/entities/download_status.dart';
import '../widgets/download_tile.dart';

const _kBg = AppTheme.background;
const _kAccent = AppTheme.sage;
const _kSub = AppTheme.textSecondary;

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
      // No AppBar: the title is part of the page now, next to its own
      // artwork, which is what lets the hills run the full height behind
      // everything below it.
      body: Stack(
        children: [
          const Align(
            alignment: Alignment.bottomCenter,
            child: MistyHills(height: 260),
          ),
          SafeArea(
            bottom: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const _DownloadsHeader(),
                Expanded(
                  child: tasksAsync.when(
                    loading: () => const Center(
                      child: CircularProgressIndicator(color: _kAccent),
                    ),
                    error: (e, _) => const Center(
                      child: Text('Could not load downloads',
                          style: TextStyle(color: _kSub)),
                    ),
                    data: (tasks) {
                      if (tasks.isEmpty) return const _DownloadsEmpty();

                      return ListView.separated(
                        padding: const EdgeInsets.only(bottom: 24),
                        itemCount: tasks.length,
                        separatorBuilder: (_, __) =>
                            const Divider(height: 1, color: AppTheme.border),
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
                              if (mounted) {
                                setState(() => _navigating = false);
                              }
                            },
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Title, one line of explanation, and the download mark in its own halo.
class _DownloadsHeader extends StatelessWidget {
  const _DownloadsHeader();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.fromLTRB(20, 14, 20, 18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Downloads',
                  style: TextStyle(
                    fontFamily: AppTheme.display,
                    fontSize: 30,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  'Save your favourite content and\naccess it anytime, anywhere.',
                  style: TextStyle(
                    fontFamily: AppTheme.text,
                    fontSize: 14.5,
                    height: 1.4,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            width: 108,
            height: 108,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SoftHalo(size: 108),
                Sparkles(size: 96, color: Colors.white),
                Icon(Icons.download_rounded,
                    size: 44, color: AppTheme.sageDark),
                Positioned(
                  right: -14,
                  top: 4,
                  child: LeafSprig(size: 84, angle: -0.5, opacity: 0.8),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The empty state — the screen most people see first, so it carries the
/// instruction for how to leave it.
class _DownloadsEmpty extends StatelessWidget {
  const _DownloadsEmpty();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
      children: [
        SizedBox(
          height: 190,
          child: Stack(
            alignment: Alignment.center,
            children: [
              const SoftHalo(size: 190),
              const Sparkles(size: 176, color: Colors.white),
              Container(
                width: 104,
                height: 104,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [AppTheme.sageLight, AppTheme.sage],
                  ),
                  borderRadius: BorderRadius.circular(26),
                  boxShadow: AppTheme.cardShadow,
                ),
                child: const Icon(Icons.cloud_download_outlined,
                    size: 46, color: Colors.white),
              ),
              const Positioned(
                left: 6,
                bottom: 34,
                child: LeafSprig(size: 92, angle: 2.9, opacity: 0.85),
              ),
              const Positioned(
                right: 6,
                bottom: 34,
                child: LeafSprig(
                  size: 92,
                  angle: 0.25,
                  opacity: 0.85,
                  flip: true,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        const Text(
          'No downloads yet',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: AppTheme.display,
            fontSize: 24,
            fontWeight: FontWeight.w600,
            color: AppTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Your saved content will appear here.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: AppTheme.text,
            fontSize: 14.5,
            color: _kSub,
          ),
        ),
        const SizedBox(height: 22),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: AppTheme.sageSoft.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(AppTheme.radiusRow),
          ),
          child: const Row(
            children: [
              Icon(Icons.info_outline_rounded,
                  size: 22, color: AppTheme.sageDark),
              SizedBox(width: 12),
              SizedBox(
                height: 34,
                child: VerticalDivider(width: 1, color: AppTheme.borderStrong),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Tap the download icon on a title to save it for offline '
                  'viewing.',
                  style: TextStyle(
                    fontFamily: AppTheme.text,
                    fontSize: 13.5,
                    height: 1.4,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
