import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_theme.dart';
import '../../application/watch_providers.dart';
import '../widgets/youtube_card.dart';

/// Free video in one place: live Zoom sessions at the top, then the
/// YouTube library.
///
/// They share a screen because they are the same thing to the person
/// using the app — free, open, and played outside it. Splitting them
/// would mean someone had to already know which tab a session lived
/// under to find out whether one was on.
class WatchScreen extends ConsumerWidget {
  const WatchScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final videosAsync = ref.watch(youtubeVideosProvider);

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
                Expanded(
                  child: Text(
                    'Watch',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                ),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: Text(
                'Free talks and teachings.',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: AppTheme.textSecondary),
              ),
            ),

            Expanded(
              child: videosAsync.when(
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
                          'Nothing on right now.\nCheck back soon.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              color: AppTheme.textSecondary, height: 1.5),
                        ),
                      ),
                    );
                  }

                  return RefreshIndicator(
                    color: AppTheme.sage,
                    onRefresh: () async {
                      ref.invalidate(youtubeVideosProvider);
                    },
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
                      children: [
                        if (videos.isNotEmpty) ...[
                          for (var i = 0; i < videos.length; i++) ...[
                            GestureDetector(
                              onTap: () => openYoutube(context, videos[i]),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  YoutubeThumbnail(video: videos[i]),
                                  const SizedBox(height: 10),
                                  Text(
                                    videos[i].title,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style:
                                        Theme.of(context).textTheme.titleMedium,
                                  ),
                                  if (videos[i].description != null &&
                                      videos[i]
                                          .description!
                                          .trim()
                                          .isNotEmpty) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      videos[i].description!,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                              color: AppTheme.textSecondary),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            if (i != videos.length - 1)
                              const SizedBox(height: 18),
                          ],
                        ],
                      ],
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
