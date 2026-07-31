import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_theme.dart';
import '../../application/watch_providers.dart';
import '../widgets/youtube_card.dart';

/// Free videos, played on YouTube. Separate from Courses because this is
/// open content used to bring people in, not something anyone pays for.
class WatchScreen extends ConsumerWidget {
  const WatchScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(youtubeVideosProvider);

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 6, 20, 0),
              child: Row(children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back_rounded, size: 20),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                const Expanded(
                  child: Text(
                    'Watch',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ),
              ]),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: Text(
                'Free talks and guided sessions on YouTube.',
                style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
              ),
            ),

            Expanded(
              child: async.when(
                loading: () => const Center(
                  child: CircularProgressIndicator(
                      color: AppTheme.sage, strokeWidth: 2),
                ),
                error: (e, _) => Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Text(
                      'Could not load videos.\n$e',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          color: AppTheme.textSecondary, height: 1.5),
                    ),
                  ),
                ),
                data: (videos) {
                  if (videos.isEmpty) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(32),
                        child: Text(
                          'No videos yet.\nCheck back soon.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              color: AppTheme.textSecondary, height: 1.5),
                        ),
                      ),
                    );
                  }

                  return RefreshIndicator(
                    color: AppTheme.sage,
                    onRefresh: () async =>
                        ref.invalidate(youtubeVideosProvider),
                    child: ListView.separated(
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
                      itemCount: videos.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 18),
                      itemBuilder: (_, i) {
                        final video = videos[i];
                        return GestureDetector(
                          onTap: () => openYoutube(context, video),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              YoutubeThumbnail(video: video),
                              const SizedBox(height: 10),
                              Text(
                                video.title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.w700,
                                  height: 1.3,
                                  color: AppTheme.textPrimary,
                                ),
                              ),
                              if (video.description != null &&
                                  video.description!.trim().isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text(
                                  video.description!,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 12.5,
                                    color: AppTheme.textSecondary,
                                    height: 1.45,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        );
                      },
                    ),
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
