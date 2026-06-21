import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_theme.dart';
import '../../../audio/application/audio_providers.dart';
import '../../../audio/domain/entities/audio_track.dart';
import '../../application/home_providers.dart';
import '../../domain/entities/audio_summary.dart';

const _kBg = Color(0xFF12082E);
const _kSurface = Color(0xFF1C1040);
const _kAccent = Color(0xFF8B5CF6);
const _kTextSec = Color(0xFFB0A8CC);

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
      backgroundColor: _kBg,
      body: SafeArea(
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_ios,
                    color: Colors.white, size: 18),
                onPressed: () => Navigator.of(context).pop(),
              ),
              Expanded(
                child: Text(widget.title,
                    style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white)),
              ),
            ]),
          ),
          if (_isSearch)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF1A0F38),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                      color: Colors.white.withValues(alpha: 0.08)),
                ),
                child: TextField(
                  controller: _controller,
                  autofocus: true,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    hintText: 'Search meditation, music, etc...',
                    hintStyle: TextStyle(color: _kTextSec),
                    prefixIcon:
                        Icon(Icons.search, color: _kTextSec),
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
                  child: CircularProgressIndicator(
                      color: _kAccent, strokeWidth: 2)),
              error: (e, _) => Center(
                child: Text('Could not load.\n$e',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: _kTextSec)),
              ),
              data: (audios) {
                if (_isSearch && _query.trim().isEmpty) {
                  return const Center(
                    child: Text('Type to search',
                        style: TextStyle(color: _kTextSec)),
                  );
                }
                if (audios.isEmpty) {
                  return const Center(
                    child: Text('Nothing found',
                        style: TextStyle(color: _kTextSec)),
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                  itemCount: audios.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(height: 10),
                  itemBuilder: (_, i) => _AudioRow(
                      audio: audios[i],
                      onTap: () => _play(audios[i])),
                );
              },
            ),
          ),
        ]),
      ),
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
          color: _kSurface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: Colors.white.withValues(alpha: 0.08), width: 1),
        ),
        child: Row(children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              gradient: const LinearGradient(
                  colors: [Color(0xFF8B5CF6), Color(0xFFEC4899)]),
            ),
            child: audio.coverArtUrl != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(audio.coverArtUrl!,
                        fit: BoxFit.cover))
                : const Icon(Icons.headphones,
                    color: Colors.white, size: 24),
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
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.white)),
                if (audio.artist != null)
                  Text(audio.artist!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 11, color: _kTextSec)),
              ],
            ),
          ),
          Container(
            width: 34,
            height: 34,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: _kAccent,
            ),
            child: const Icon(Icons.play_arrow,
                color: Colors.white, size: 18),
          ),
        ]),
      ),
    );
  }
}
