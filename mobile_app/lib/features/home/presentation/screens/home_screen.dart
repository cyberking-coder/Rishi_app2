import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_theme.dart';
import '../../../../app/widgets/soft_background.dart';
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
import '../../../profile/application/profile_providers.dart';
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

  void _play(AudioSummary audio) {
    ref.read(audioHandlerProvider).playSingleTrack(AudioTrack(
      id: audio.id,
      title: audio.title,
      artist: audio.artist,
      coverArtUrl: audio.coverArtUrl,
      durationSeconds: audio.durationSeconds,
    ));
    context.push('/now-playing');
  }

  @override
  Widget build(BuildContext context) {
    final accessAsync = ref.watch(accessStateProvider);
    final access = accessAsync.valueOrNull;
    if (access != null) _onAccess(access);
    final expired = access?.isExpired ?? false;

    if (expired) {
      return Scaffold(
        backgroundColor: AppTheme.canvas,
        body: Stack(children: [
          const SoftBackground(),
          SafeArea(child: AccessExpiredView(access: access!)),
        ]),
      );
    }

    final featuredAsync = ref.watch(featuredAudiosProvider);
    final continueAsync = ref.watch(continueListeningProvider);
    final categoriesAsync = ref.watch(categoriesProvider);

    return Scaffold(
      backgroundColor: AppTheme.canvas,
      body: Stack(children: [
        const SoftBackground(),
        SafeArea(
          child: Column(children: [
            Expanded(
              child: CustomScrollView(slivers: [
                // ── Header ──
                SliverToBoxAdapter(child: _buildHeader()),
                // ── Search bar ──
                SliverToBoxAdapter(
                  child: _SearchBar(onTap: () => context.push('/search')),
                ),
                // ── Daily featured card ──
                SliverToBoxAdapter(child: featuredAsync.when(
                  loading: () => const SizedBox(height: 80),
                  error: (_, __) => const SizedBox.shrink(),
                  data: (audios) => audios.isEmpty
                      ? const SizedBox.shrink()
                      : _DailyCard(audio: audios.first, onPlay: () => _play(audios.first)),
                )),
                // ── Featured For You ──
                SliverToBoxAdapter(child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Featured For You',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                      Text('See All', style: TextStyle(fontSize: 12, color: AppTheme.accentBright)),
                    ],
                  ),
                )),
                SliverToBoxAdapter(child: featuredAsync.when(
                  loading: () => const SizedBox(height: 100),
                  error: (_, __) => SectionError(onRetry: () => ref.invalidate(featuredAudiosProvider)),
                  data: (audios) {
                    final rest = audios.length > 1 ? audios.sublist(1) : audios;
                    return _MiniCardRow(audios: rest, onPlay: _play);
                  },
                )),
                // ── Categories ──
                SliverToBoxAdapter(child: categoriesAsync.when(
                  loading: () => const SizedBox.shrink(),
                  error: (_, __) => const SizedBox.shrink(),
                  data: (cats) => _CategoriesRow(
                    categories: cats,
                    onTap: (c) => context.push('/category/${c.id}', extra: c.name),
                  ),
                )),
                const SliverToBoxAdapter(child: SizedBox(height: 16)),
              ]),
            ),
            // ── Continue Listening pinned bar ──
            continueAsync.when(
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
              data: (items) {
                if (items.isEmpty) return const SizedBox.shrink();
                final item = items.first;
                return _ContinueBar(
                  item: item,
                  onTap: () {
                    ref.read(audioHandlerProvider).playSingleTrack(AudioTrack(
                      id: item.audioId,
                      title: item.title,
                      artist: item.teacher,
                      coverArtUrl: item.coverArtUrl,
                      durationSeconds: item.durationSeconds,
                    ));
                    context.push('/now-playing');
                  },
                );
              },
            ),
          ]),
        ),
      ]),
    );
  }

  Widget _buildHeader() {
    final h = DateTime.now().hour;
    final greeting = h < 12 ? 'Good Morning' : h < 17 ? 'Good Afternoon' : 'Good Evening';
    final profile = ref.watch(userProfileProvider).valueOrNull;
    final raw = profile?.displayName?.trim().isNotEmpty == true
        ? profile!.displayName!.trim()
        : (profile?.email.split('@').first ?? 'there');
    final name = raw.isEmpty ? 'there' : raw;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            RichText(text: TextSpan(children: [
              TextSpan(text: 'Hi, $name ', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: Colors.white)),
              const TextSpan(text: '👋', style: TextStyle(fontSize: 22)),
            ])),
            const SizedBox(height: 2),
            Text(greeting, style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
          ]),
        ),
        IconButton(
          icon: const Icon(Icons.download_outlined, color: AppTheme.textSecondary),
          onPressed: () => context.push('/downloads'),
        ),
        GestureDetector(
          onTap: () => context.push('/profile'),
          child: Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: AppTheme.heroGradient,
              boxShadow: [BoxShadow(color: AppTheme.accent.withValues(alpha: 0.4), blurRadius: 12, offset: const Offset(0, 4))],
            ),
            child: const Icon(Icons.person, color: Colors.white, size: 22),
          ),
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────

class _SearchBar extends StatelessWidget {
  final VoidCallback onTap;
  const _SearchBar({required this.onTap});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 46,
          decoration: BoxDecoration(
            color: const Color(0xFF1C1640),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppTheme.line),
          ),
          child: const Row(children: [
            SizedBox(width: 14),
            Icon(Icons.search, color: AppTheme.textDim, size: 18),
            SizedBox(width: 10),
            Text('Search meditation, music, etc...', style: TextStyle(color: AppTheme.textDim, fontSize: 13)),
          ]),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────

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
          gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight,
              colors: [Color(0xFF2D1F6E), Color(0xFF1C1640)]),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppTheme.line),
        ),
        child: Row(children: [
          Container(
            width: 54, height: 54,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight,
                  colors: [Color(0xFFF59E0B), Color(0xFFEC4899)]),
            ),
            child: audio.coverArtUrl != null
                ? ClipRRect(borderRadius: BorderRadius.circular(14),
                    child: Image.network(audio.coverArtUrl!, fit: BoxFit.cover))
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Daily Meditation', style: TextStyle(fontSize: 10, color: AppTheme.accentBright)),
              const SizedBox(height: 2),
              Text(audio.title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
              Text('Mindfulness', style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: onPlay,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  decoration: BoxDecoration(gradient: AppTheme.heroGradient, borderRadius: BorderRadius.circular(10)),
                  child: const Text('Play Now', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white)),
                ),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────

class _MiniCardRow extends StatelessWidget {
  final List<AudioSummary> audios;
  final void Function(AudioSummary) onPlay;
  static const _gradients = [
    [Color(0xFF3730A3), Color(0xFF1E1B4B)],
    [Color(0xFF7C3AED), Color(0xFF4C1D95)],
    [Color(0xFF9333EA), Color(0xFF6D28D9)],
  ];
  const _MiniCardRow({required this.audios, required this.onPlay});

  @override
  Widget build(BuildContext context) {
    if (audios.isEmpty) return const SizedBox.shrink();
    final items = audios.take(3).toList();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(children: List.generate(items.length, (i) {
        final colors = _gradients[i % _gradients.length];
        return Expanded(
          child: GestureDetector(
            onTap: () => onPlay(items[i]),
            child: Container(
              height: 100,
              margin: EdgeInsets.only(right: i < items.length - 1 ? 10 : 0),
              decoration: BoxDecoration(
                gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: colors),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Stack(children: [
                if (items[i].coverArtUrl != null)
                  ClipRRect(borderRadius: BorderRadius.circular(16),
                      child: Image.network(items[i].coverArtUrl!, fit: BoxFit.cover,
                          width: double.infinity, height: double.infinity)),
                Positioned(left: 10, bottom: 10, right: 10,
                  child: Text(items[i].title, maxLines: 3, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white, height: 1.2))),
              ]),
            ),
          ),
        );
      })),
    );
  }
}

// ─────────────────────────────────────────────────────────────

class _CategoriesRow extends StatelessWidget {
  final List<CategorySummary> categories;
  final void Function(CategorySummary) onTap;
  static const _emojis = ['🌙', '🧘', '🎯', '🛡️', '🌿', '💤', '🔥', '🪷'];
  const _CategoriesRow({required this.categories, required this.onTap});

  @override
  Widget build(BuildContext context) {
    if (categories.isEmpty) return const SizedBox.shrink();
    final items = categories.take(4).toList();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Padding(
        padding: EdgeInsets.fromLTRB(20, 20, 20, 12),
        child: Text('Categories', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
      ),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(items.length, (i) {
            return GestureDetector(
              onTap: () => onTap(items[i]),
              child: Column(children: [
                Container(width: 56, height: 56,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.07),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppTheme.line),
                  ),
                  child: Center(child: Text(_emojis[i % _emojis.length], style: const TextStyle(fontSize: 22)))),
                const SizedBox(height: 6),
                SizedBox(
                  width: 64,
                  child: Text(items[i].name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
                ),
              ]),
            );
          }),
        ),
      ),
    ]);
  }
}

// ─────────────────────────────────────────────────────────────

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
        child: Row(children: [
          const SizedBox(width: 10),
          Container(width: 42, height: 42,
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), gradient: AppTheme.heroGradient),
            child: item.coverArtUrl != null
                ? ClipRRect(borderRadius: BorderRadius.circular(12),
                    child: Image.network(item.coverArtUrl!, fit: BoxFit.cover))
                : null),
          const SizedBox(width: 10),
          Expanded(child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Continue Listening', style: TextStyle(fontSize: 9, color: AppTheme.textDim)),
            Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
          ])),
          GestureDetector(
            onTap: onTap,
            child: Container(width: 34, height: 34,
              decoration: BoxDecoration(shape: BoxShape.circle, gradient: AppTheme.heroGradient,
                boxShadow: [BoxShadow(color: AppTheme.accent.withValues(alpha: 0.4), blurRadius: 10)]),
              child: const Icon(Icons.play_arrow, color: Colors.white, size: 18)),
          ),
          const SizedBox(width: 10),
        ]),
      ),
    );
  }
}
