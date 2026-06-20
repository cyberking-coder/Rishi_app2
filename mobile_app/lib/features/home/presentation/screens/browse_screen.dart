import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_theme.dart';
import '../../../../app/widgets/soft_background.dart';
import '../../../audio/application/audio_providers.dart';
import '../../../audio/domain/entities/audio_track.dart';
import '../../application/home_providers.dart';
import '../../domain/entities/audio_summary.dart';

/// One screen serving both search and category browsing. When [categoryId] is
/// given it lists that category; otherwise it shows a search box.
class BrowseScreen extends ConsumerStatefulWidget {
  final String? categoryId;
  final String title;
  const BrowseScreen({super.key, this.categoryId, required this.title});

  @override
  ConsumerState<BrowseScreen> createState() => _BrowseScreenState();
}

class _BrowseScreenState extends ConsumerState<BrowseScreen> {
  final _controller = TextEditingController();
  String _query = '';

  bool get _isSearch => widget.categoryId == null;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _play(AudioSummary a) {
    ref.read(audioHandlerProvider).playSingleTrack(AudioTrack(
          id: a.id,
          title: a.title,
          artist: a.artist,
          coverArtUrl: a.coverArtUrl,
          durationSeconds: a.durationSeconds,
        ));
    context.push('/now-playing');
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<List<AudioSummary>> results = _isSearch
        ? ref.watch(searchAudiosProvider(_query))
        : ref.watch(categoryAudiosProvider(widget.categoryId!));

    return Scaffold(
      backgroundColor: AppTheme.canvas,
      body: Stack(children: [
        const SoftBackground(),
        SafeArea(
          child: Column(children: [
            // Top bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back_ios, size: 18),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                Expanded(
                  child: Text(widget.title,
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w600)),
                ),
              ]),
            ),
            if (_isSearch)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF1C1640),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppTheme.line),
                  ),
                  child: TextField(
                    controller: _controller,
                    autofocus: true,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      hintText: 'Search meditation, music, etc...',
                      hintStyle: TextStyle(color: AppTheme.textDim),
                      prefixIcon: Icon(Icons.search, color: AppTheme.textDim),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                    ),
                    onChanged: (v) => setState(() => _query = v),
                  ),
                ),
              ),
            Expanded(
              child: results.when(
                loading: () => const Center(
                    child: CircularProgressIndicator(color: AppTheme.accent)),
                error: (e, _) => Center(
                  child: Text('Could not load.\n$e',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AppTheme.textSecondary)),
                ),
                data: (audios) {
                  if (_isSearch && _query.trim().isEmpty) {
                    return const Center(
                      child: Text('Type to search',
                          style: TextStyle(color: AppTheme.textDim)),
                    );
                  }
                  if (audios.isEmpty) {
                    return const Center(
                      child: Text('Nothing found',
                          style: TextStyle(color: AppTheme.textDim)),
                    );
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                    itemCount: audios.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (_, i) =>
                        _AudioRow(audio: audios[i], onTap: () => _play(audios[i])),
                  );
                },
              ),
            ),
          ]),
        ),
      ]),
    );
  }
}

class _AudioRow extends StatelessWidget {
  final AudioSummary audio;
  final VoidCallback onTap;
  const _AudioRow({required this.audio, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.line),
        ),
        child: Row(children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              gradient: AppTheme.heroGradient,
            ),
            child: audio.coverArtUrl != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(audio.coverArtUrl!, fit: BoxFit.cover))
                : const Icon(Icons.headphones, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(audio.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600)),
                if (audio.artist != null)
                  Text(audio.artist!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 11, color: AppTheme.textSecondary)),
              ],
            ),
          ),
          Container(
            width: 34,
            height: 34,
            decoration: const BoxDecoration(
                shape: BoxShape.circle, gradient: AppTheme.heroGradient),
            child: const Icon(Icons.play_arrow, color: Colors.white, size: 18),
          ),
        ]),
      ),
    );
  }
}
