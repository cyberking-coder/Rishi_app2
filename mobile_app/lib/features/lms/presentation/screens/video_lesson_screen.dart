import 'package:chewie/chewie.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show FunctionException;
import 'package:video_player/video_player.dart';

import '../../../../app/theme/app_theme.dart';
import '../../application/lms_providers.dart';
import '../../domain/entities/lesson.dart';

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
  String? _errorDetails;

  /// Whether the stream actually started. Returned to the course screen
  /// on pop so a lesson that failed to load isn't ticked off as done.
  bool _played = false;

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
        _played = true;
        _controller = controller;
        _chewie = ChewieController(
          videoPlayerController: controller,
          autoPlay: true,
          // Lessons are watched deliberately, not doom-scrolled — looping
          // would obscure that one finished.
          looping: false,
          allowPlaybackSpeedChanging: true,
          materialProgressColors: ChewieProgressColors(
            playedColor: AppTheme.sage,
            handleColor: AppTheme.sage,
            backgroundColor: Colors.white24,
            bufferedColor: Colors.white38,
          ),
        );
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = _describeError(e);
          _errorDetails = _errorDetail(e);
        });
      }
    }
  }

  /// Turns whatever was thrown into something a viewer can act on.
  ///
  /// Raw toString() output was reaching the screen verbatim — an
  /// ExoPlayer "Source error" stack fragment tells someone watching a
  /// meditation course nothing at all. The edge function already returns
  /// a written explanation for the cases it can identify, so prefer that
  /// whenever it's there.
  String _describeError(Object e) {
    if (e is FunctionException) {
      final details = e.details;
      if (details is Map && details['error'] is String) {
        return details['error'] as String;
      }
      return 'Could not start this video (${e.status}).';
    }
    if (e is PlatformException) {
      return 'This video could not be played. It may still be processing '
          '— please try again in a few minutes.';
    }
    return e.toString();
  }

  /// The underlying failure, shown small beneath the friendly message.
  ///
  /// ExoPlayer names the actual cause in here — "Response code: 403" for
  /// a rejected token, "404" for a manifest that isn't there, a codec
  /// name when the file itself is the problem. Hiding all of it behind
  /// "may still be processing" made the screen calmer and useless: every
  /// distinct failure looked identical.
  String? _errorDetail(Object e) {
    if (e is PlatformException) {
      return [e.code, e.message].where((s) => s != null).join(': ');
    }
    return null;
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
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.of(context).pop(_played);
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF141B18),
        body: SafeArea(
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_rounded,
                    color: Colors.white, size: 20),
                onPressed: () => Navigator.of(context).pop(_played),
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
      ),
    );
  }

  Widget _body() {
    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.error_outline, color: Colors.white70, size: 40),
          const SizedBox(height: 12),
          Text(_error!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70, height: 1.5)),
          if (_errorDetails != null) ...[
            const SizedBox(height: 8),
            Text(_errorDetails!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: Colors.white38, fontSize: 11, height: 1.4)),
          ],
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () {
              setState(() {
                _error = null;
                _errorDetails = null;
              });
              _load();
            },
            child: const Text('Try again'),
          ),
        ]),
      );
    }

    if (_chewie == null) {
      return const CircularProgressIndicator(color: Colors.white70, strokeWidth: 2);
    }

    return AspectRatio(
      aspectRatio: _controller!.value.aspectRatio,
      child: Chewie(controller: _chewie!),
    );
  }
}
