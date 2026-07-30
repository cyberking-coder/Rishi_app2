import 'package:chewie/chewie.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';

import '../../application/lms_providers.dart';
import '../../domain/entities/lesson.dart';

const _kBg = Color(0xFF12082E);
const _kAccent = Color(0xFF8B5CF6);
const _kTextSec = Color(0xFFB0A8CC);

class VideoLessonScreen extends ConsumerStatefulWidget {
  final Lesson lesson;

  const VideoLessonScreen({super.key, required this.lesson});

  @override
  ConsumerState<VideoLessonScreen> createState() => _VideoLessonScreenState();
}

class _VideoLessonScreenState extends ConsumerState<VideoLessonScreen> {
  VideoPlayerController? _controller;
  ChewieController? _chewie;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final url = await ref
          .read(videoRemoteDataSourceProvider)
          .issuePlaybackUrl(widget.lesson.videoId!);

      final controller = VideoPlayerController.networkUrl(Uri.parse(url));
      await controller.initialize();
      if (!mounted) {
        controller.dispose();
        return;
      }

      setState(() {
        _controller = controller;
        _chewie = ChewieController(
          videoPlayerController: controller,
          autoPlay: true,
          // Lessons are watched deliberately, not doom-scrolled — looping
          // would obscure that one finished.
          looping: false,
          allowPlaybackSpeedChanging: true,
          materialProgressColors: ChewieProgressColors(
            playedColor: _kAccent,
            handleColor: _kAccent,
            backgroundColor: Colors.white24,
            bufferedColor: Colors.white38,
          ),
        );
      });
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  @override
  void dispose() {
    // Chewie must go first: it holds a reference to the video controller
    // and will touch it during its own teardown.
    _chewie?.dispose();
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
                child: Text(widget.lesson.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white)),
              ),
            ]),
          ),
          Expanded(child: Center(child: _body())),
        ]),
      ),
    );
  }

  Widget _body() {
    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.error_outline, color: _kTextSec, size: 40),
          const SizedBox(height: 12),
          Text(_error!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: _kTextSec, height: 1.5)),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () {
              setState(() => _error = null);
              _load();
            },
            child: const Text('Try again'),
          ),
        ]),
      );
    }

    if (_chewie == null) {
      return const CircularProgressIndicator(color: _kAccent, strokeWidth: 2);
    }

    return AspectRatio(
      aspectRatio: _controller!.value.aspectRatio,
      child: Chewie(controller: _chewie!),
    );
  }
}
