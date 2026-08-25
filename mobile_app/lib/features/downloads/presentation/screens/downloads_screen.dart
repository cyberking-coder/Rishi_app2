import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_theme.dart';
import '../../../../core/config/purchase_config.dart';
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
      // No AppBar: the title is part of the page, so it can take the
      // display size the design gives every tab heading.
      body: SafeArea(
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
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                    itemCount: tasks.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
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
    );
  }
}

/// Just the title. The design gives every tab a bare one-word heading —
/// the strapline and the big download glyph that were here explained
/// the screen to somebody already on it, and the empty state below says
/// the same thing better, where it is actually needed.
class _DownloadsHeader extends StatelessWidget {
  const _DownloadsHeader();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.fromLTRB(20, 10, 20, 16),
      child: Text('Downloads', style: AppTheme.displayLarge),
    );
  }
}

/// The empty state — the screen most people see first, so it carries the
/// instruction for how to leave it.
class _DownloadsEmpty extends StatelessWidget {
  const _DownloadsEmpty();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Centred in whatever room is left, with the hint pinned to the
        // bottom. Previously this was a scrolling list, so on a tall
        // phone the whole empty state huddled under the header with the
        // rest of the screen blank beneath it.
        Expanded(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.arrow_circle_down_outlined,
                      size: 64, color: Color(0xFFBCB4CC)),
                  const SizedBox(height: 16),
                  const Text(
                    'No downloads',
                    textAlign: TextAlign.center,
                    style: AppTheme.headline,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Sessions you download stay on this device, so you '
                    'can play them without a connection.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: AppTheme.text,
                      fontSize: 15,
                      height: 1.5,
                      color: _kSub,
                    ),
                  ),
                  const SizedBox(height: 24),
                  // The one way out of an empty screen, stated as a
                  // button rather than left as something to work out
                  // from the tab bar.
                  //
                  // Worded off kEducationFramingEnabled like every other
                  // label naming the catalogue. Hardcoding "courses"
                  // here would have put the education word back on the
                  // iOS build, in the one place nobody thinks to check
                  // — a button that only appears on an empty screen.
                  FilledButton(
                    onPressed: () => context.go('/courses'),
                    child: Text(kEducationFramingEnabled
                        ? 'Browse courses'
                        : 'Browse videos'),
                  ),
                ],
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            decoration: BoxDecoration(
              color: const Color(0x0C1E1830),
              borderRadius: BorderRadius.circular(AppTheme.radiusRow),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_rounded, size: 17, color: _kSub),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Tap the download button on any title to save it here.',
                    style: TextStyle(
                      fontFamily: AppTheme.text,
                      fontSize: 13,
                      height: 1.45,
                      color: Color(0xFF544A6E),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
