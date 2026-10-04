import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_theme.dart';
import '../../../../app/widgets/remote_image.dart';
import '../../../audio/application/audio_providers.dart';
import '../../../audio/domain/entities/audio_track.dart';
import '../../../audio/presentation/utils/audio_navigation.dart';
import '../../application/favorites_providers.dart';

/// Favourites — audios the user has hearted. Plays them as one continuous
/// playlist that loops (one after another, then back to the first) until the
/// user stops. Audio only, by design.
class FavoritesScreen extends ConsumerWidget {
  const FavoritesScreen({super.key});

  Future<void> _playFrom(WidgetRef ref, BuildContext context,
      List<AudioTrack> tracks, int index) async {
    await ref
        .read(audioHandlerProvider)
        .loadPlaylist(tracks, startIndex: index, loopAll: true);
    if (context.mounted) openNowPlaying(context);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favsAsync = ref.watch(favoriteAudiosProvider);

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          color: AppTheme.sage,
          onRefresh: () async => ref.invalidate(favoriteAudiosProvider),
          child: favsAsync.when(
            loading: () =>
                const Center(child: CircularProgressIndicator(color: AppTheme.sage)),
            error: (_, __) => ListView(children: const [
              SizedBox(height: 120),
              Center(
                child: Text('Could not load favourites',
                    style: TextStyle(color: AppTheme.textSecondary)),
              ),
            ]),
            data: (tracks) {
              return ListView(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
                children: [
                  const Text('Favourites', style: AppTheme.displayLarge),
                  const SizedBox(height: 14),
                  if (tracks.isEmpty)
                    const _EmptyFavorites()
                  else ...[
                    _Controls(
                      count: tracks.length,
                      onPlay: () => _playFrom(ref, context, tracks, 0),
                      onShuffle: () {
                        final shuffled = [...tracks]..shuffle();
                        _playFrom(ref, context, shuffled, 0);
                      },
                    ),
                    const SizedBox(height: 14),
                    for (var i = 0; i < tracks.length; i++)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _FavoriteRow(
                          track: tracks[i],
                          onTap: () => _playFrom(ref, context, tracks, i),
                          onUnfavorite: () => ref
                              .read(favoriteIdsProvider.notifier)
                              .toggle(tracks[i].id),
                        ),
                      ),
                  ],
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _Controls extends StatelessWidget {
  final int count;
  final VoidCallback onPlay;
  final VoidCallback onShuffle;
  const _Controls(
      {required this.count, required this.onPlay, required this.onShuffle});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text('$count saved',
            style: const TextStyle(
                fontFamily: AppTheme.text,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppTheme.textSecondary)),
        const Spacer(),
        TextButton.icon(
          onPressed: onShuffle,
          icon: const Icon(Icons.shuffle_rounded, size: 18),
          label: const Text('Shuffle'),
        ),
        const SizedBox(width: 6),
        FilledButton.icon(
          onPressed: onPlay,
          icon: const Icon(Icons.play_arrow_rounded),
          label: const Text('Play'),
        ),
      ],
    );
  }
}

class _FavoriteRow extends StatelessWidget {
  final AudioTrack track;
  final VoidCallback onTap;
  final VoidCallback onUnfavorite;
  const _FavoriteRow(
      {required this.track, required this.onTap, required this.onUnfavorite});

  String get _meta {
    final secs = track.durationSeconds;
    if (secs == null) return track.artist ?? '';
    final mins = (secs / 60).round();
    final left = track.artist;
    return left == null || left.isEmpty ? '$mins min' : '$left · $mins min';
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: AppTheme.glassSurface(),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                width: 52,
                height: 52,
                child: RemoteImage(
                  url: track.coverArtUrl,
                  fallback: const ColoredBox(
                    color: AppTheme.sageSoft,
                    child: Icon(Icons.headphones_rounded,
                        color: AppTheme.sageLight),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(track.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontFamily: AppTheme.text,
                          fontSize: 15.5,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimary)),
                  if (_meta.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(_meta,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontFamily: AppTheme.text,
                            fontSize: 12.5,
                            color: AppTheme.textSecondary)),
                  ],
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.favorite_rounded, color: AppTheme.sage),
              tooltip: 'Remove from favourites',
              onPressed: onUnfavorite,
            ),
            IconButton(
              icon: const Icon(Icons.play_circle_fill_rounded,
                  color: AppTheme.sage, size: 30),
              onPressed: onTap,
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyFavorites extends StatelessWidget {
  const _EmptyFavorites();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(top: 80),
      child: Column(
        children: [
          Icon(Icons.favorite_border_rounded, size: 60, color: AppTheme.sage),
          SizedBox(height: 16),
          Text('No favourites yet', style: AppTheme.headline),
          SizedBox(height: 8),
          Text(
            'Tap the heart on any audio to save it here, then play them all '
            'back to back.',
            textAlign: TextAlign.center,
            style: TextStyle(
                fontFamily: AppTheme.text,
                fontSize: 14.5,
                height: 1.5,
                color: AppTheme.textSecondary),
          ),
        ],
      ),
    );
  }
}
