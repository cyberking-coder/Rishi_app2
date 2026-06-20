import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_theme.dart';
import '../../../../app/widgets/soft_background.dart';
import '../../../../core/utils/responsive.dart';
import '../../../access/application/access_providers.dart';
import '../../../access/domain/access_state.dart';
import '../../../access/presentation/access_expired_view.dart';
import '../../../access/presentation/next_event_popup.dart';
import '../../../audio/application/audio_providers.dart';
import '../../../audio/domain/entities/audio_track.dart';
import '../../../downloads/application/download_providers.dart';
import '../../application/home_providers.dart';
import '../../domain/entities/audio_summary.dart';
import '../../domain/entities/category_summary.dart';
import '../../domain/entities/continue_listening_item.dart';
import '../widgets/fade_slide_in.dart';
import '../widgets/section_error.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  bool _popupShown = false;
  bool _purged = false;

  void _onAccess(AccessState access) {
    if (access.isExpired && !_purged) {
      _purged = true;
      ref.read(downloadRepositoryProvider).purgeAll();
      return;
    }
    if (access.hasAccess && access.shouldShowPopup && !_popupShown) {
      _popupShown = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) NextEventPopup.show(context, access);
      });
    }
  }

  void _playAudio(AudioSummary audio) {
    ref.read(audioHandlerProvider).playSingleTrack(
          AudioTrack(
            id: audio.id,
            title: audio.title,
            artist: audio.artist,
            coverArtUrl: audio.coverArtUrl,
            durationSeconds: audio.durationSeconds,
          ),
        );
    context.push('/now-playing');
  }

  @override
  Widget build(BuildContext context) {
    final accessAsync = ref.watch(accessStateProvider);
    final access = accessAsync.valueOrNull;
    if (access != null) _onAccess(access);
    final expired = access?.isExpired ?? false;

    return Scaffold(
      backgroundColor: AppTheme.canvas,
      body: Stack(
        children: [
          const SoftBackground(),
          SafeArea(
            child: expired
                ? AccessExpiredView(access: access!)
                : _HomeBody(onPlay: _playAudio),
          ),
        ],
      ),
    );
  }
}

class _HomeBody extends ConsumerWidget {
  final void Function(AudioSummary) onPlay;
  const _HomeBody({required this.onPlay});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final featuredAsync = ref.watch(featuredAudiosProvider);
    final continueAsync = ref.watch(continueListeningProvider);
    final categoriesAsync = ref.watch(categoriesProvider);

    return Column(
      children: [
        Expanded(
          child: CustomScrollView(
            slivers: [
              // Header
              SliverToBoxAdapter(child: _Header(
                onProfile: () => context.push('/profile'),
                onDownloads: () => context.push('/downloads'),
              )),
              // Search bar
              const SliverToBoxAdapter(child: _SearchBar()),
              // Daily featured card
              SliverToBoxAdapter(child: featuredAsync.when(
                loading: () => const SizedBox(height: 88),
                error: (_, __) => const SizedBox.shrink(),
                data: (audios) => audios.isEmpty
                    ? const SizedBox.shrink()
                    : _DailyCard(audio: audios.first, onPlay: () => _playAudio(audios.first, context, ref)),
              )),
              // Featured For You
              SliverToBoxAdapter(child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Featured For You',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                    Text('See All',
                        style: TextStyle(fontSize: 12, color: AppTheme.accentBright)),
                  ],
                ),
              )),
              SliverToBoxAdapter(child: featuredAsync.when(
                loading: () => const SizedBox(height: 100),
                error: (_, __) => SectionError(onRetry: () => ref.invalidate(featuredAudiosProvider)),
                data: (audios) {
                  final items = audios.length > 1 ? audios.sublist(1) : audios;
                  return _MiniCardRow(audios: items, onPlay: (a) => _playAudio(a, context, ref));
                },
              )),
              // Categories
              SliverToBoxAdapter(child: categoriesAsync.when(
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
                data: (cats) => _CategoriesRow(categories: cats),
              )),
              const SliverToBoxAdapter(child: SizedBox(height: 20)),
            ],
          ),
        ),
        // Continue listening pinned at bottom
        continueAsync.when(
          loading: () => const SizedBox.shrink(),
          error: (_, __) => const SizedBox.shrink(),
          data: (items) => items.isEmpty
              ? const SizedBox.shrink()
              : _ContinueBar(item: items.first, onTap: () {
                  final item = items.first;
                  ref.read(audioHandlerProvider).playSingleTrack(AudioTrack(
                    id: item.audioId,
                    title: item.title,
                    artist: item.teacher,
                    coverArtUrl: item.coverArtUrl,
                    durationSeconds: item.durationSeconds,
                  ));
                  context.push('/now-playing');
                }),
        ),
      ],
    );
  }

  void _playAudio(AudioSummary audio, BuildContext context, WidgetRef ref) {
    ref.read(audioHandlerProvider).playSingleTrack(AudioTrack(
      id: audio.id,
      title: audio.title,
      artist: audio.artist,
      coverArtUrl: audio.coverArtUrl,
      durationSeconds: audio.durationSeconds,
    ));
    context.push('/now-playing');
  }
}

class _Header extends StatelessWidget {
  final VoidCallback onProfile;
  final VoidCallback onDownloads;
  const _Header({required this.onProfile, required this.onDownloads});

  String get _greeting {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good Morning';
    if (h < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RichText(
                  text: const TextSpan(
                    children: [
                      TextSpan(
                        text: 'Hi, Arjun ',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      TextSpan(text: '👋', style: TextStyle(fontSize: 22)),
                    ],
                  ),
                ),
                const SizedBox(height: 2),
                Text(_greeting,
                    style: const TextStyle(
                        fontSize: 13, color: AppTheme.textSecondary)),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.download_outlined, color: AppTheme.textSecondary),
            onPressed: onDownloads,
          ),
          GestureDetector(
            onTap: onProfile,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                gradient: AppTheme.heroGradient,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.accent.withValues(alpha: 0.4),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Icon(Icons.person, color: Colors.white, size: 22),
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchBar extends StatelessWidget {
  const _SearchBar();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
      child: Container(
        height: 46,
        decoration: BoxDecoration(
          color: const Color(0xFF1C1640),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.line),
        ),
        child: Row(
          children: [
            const SizedBox(width: 14),
            const Icon(Icons.search, color: AppTheme.textDim, size: 18),
            const SizedBox(width: 10),
            Text('Search meditation, music, etc...',
                style: const TextStyle(color: AppTheme.textDim, fontSize: 13)),
          ],
        ),
      ),
    );
  }
}

class _DailyCard extends StatelessWidget {
  final AudioSummary audio;
  final VoidCallback onPlay;
  const _DailyCard({required this.audio, required this.onPlay});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF2D1F6E), Color(0xFF1C1640)],
          ),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppTheme.line),
        ),
        child: Row(
          children: [
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFFF59E0B), Color(0xFFEC4899)],
                ),
              ),
              child: audio.coverArtUrl != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: Image.network(audio.coverArtUrl!, fit: BoxFit.cover),
                    )
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Daily Meditation',
                      style: TextStyle(fontSize: 10, color: AppTheme.accentBright)),
                  const SizedBox(height: 2),
                  Text(audio.title,
                      style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimary)),
                  Text('${audio.durationSeconds != null ? _fmt(audio.durationSeconds!) : "10"} min · Mindfulness',
                      style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: onPlay,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      decoration: BoxDecoration(
                        gradient: AppTheme.heroGradient,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Text('Play Now',
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Colors.white)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _fmt(int seconds) {
    final m = seconds ~/ 60;
    return m > 0 ? '$m' : '<1';
  }
}

class _MiniCardRow extends StatelessWidget {
  final List<AudioSummary> audios;
  final void Function(AudioSummary) onPlay;
  static const List<List<Color>> _gradients = [
    [Color(0xFF3730A3), Color(0xFF1E1B4B)],
    [Color(0xFF7C3AED), Color(0xFF4C1D95)],
    [Color(0xFF9333EA), Color(0xFF6D28D9)],
  ];

  const _MiniCardRow({required this.audios, required this.onPlay});

  @override
  Widget build(BuildContext context) {
    final items = audios.take(3).toList();
    if (items.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: List.generate(items.length > 3 ? 3 : items.length, (i) {
          final audio = items[i];
          final colors = _gradients[i % _gradients.length];
          return Expanded(
            child: GestureDetector(
              onTap: () => onPlay(audio),
              child: Container(
                height: 100,
                margin: EdgeInsets.only(right: i < 2 ? 10 : 0),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: colors,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Stack(
                  children: [
                    if (audio.coverArtUrl != null)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Image.network(audio.coverArtUrl!,
                            fit: BoxFit.cover,
                            width: double.infinity,
                            height: double.infinity),
                      ),
                    Positioned(
                      left: 10,
                      bottom: 10,
                      right: 10,
                      child: Text(audio.title,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                              height: 1.2)),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _CategoriesRow extends StatelessWidget {
  final List<CategorySummary> categories;
  const _CategoriesRow({required this.categories});

  static const List<String> _emojis = ['🌙', '🧘', '🎯', '🛡️'];
  static const List<String> _labels = ['Sleep', 'Relaxation', 'Focus', 'Anxiety'];

  @override
  Widget build(BuildContext context) {
    final items = categories.isEmpty
        ? List.generate(4, (i) => _labels[i])
        : categories.take(4).map((c) => c.name).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(20, 18, 20, 12),
          child: Text('Categories',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(items.length > 4 ? 4 : items.length, (i) {
              return Column(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.07),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppTheme.line),
                    ),
                    child: Center(
                      child: Text(_emojis[i % _emojis.length],
                          style: const TextStyle(fontSize: 22)),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(items[i],
                      style: const TextStyle(
                          fontSize: 10, color: AppTheme.textSecondary)),
                ],
              );
            }),
          ),
        ),
      ],
    );
  }
}

class _ContinueBar extends StatelessWidget {
  final ContinueListeningItem item;
  final VoidCallback onTap;
  const _ContinueBar({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Container(
        height: 62,
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.line),
        ),
        child: Row(
          children: [
            const SizedBox(width: 10),
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                gradient: AppTheme.heroGradient,
              ),
              child: item.coverArtUrl != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(item.coverArtUrl!, fit: BoxFit.cover),
                    )
                  : null,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Continue Listening',
                      style: TextStyle(fontSize: 9, color: AppTheme.textDim)),
                  Text(item.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
            GestureDetector(
              onTap: onTap,
              child: Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: AppTheme.heroGradient,
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.accent.withValues(alpha: 0.4),
                      blurRadius: 10,
                    ),
                  ],
                ),
                child: const Icon(Icons.play_arrow, color: Colors.white, size: 18),
              ),
            ),
            const SizedBox(width: 10),
          ],
        ),
      ),
    );
  }
}
