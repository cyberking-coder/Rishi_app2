import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../domain/entities/playback_source.dart';
import '../domain/entities/video_quality.dart';
import '../domain/repositories/player_repository.dart';

enum PlayerLoadStatus { loading, ready, error }

const List<double> kAvailablePlaybackSpeeds = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0];

/// Owns the `video_player` controller for one video and everything around
/// it: quality switching, speed, fullscreen chrome, resume-on-start, and
/// periodic watch-progress sync. Exposed to widgets via ChangeNotifier so
/// the player UI rebuilds on every video_player tick without going through
/// Riverpod state for every frame.
class OttPlayerController extends ChangeNotifier {
  final String videoId;
  final PlayerRepository _repository;

  OttPlayerController(this.videoId, this._repository);

  static const _progressSyncInterval = Duration(seconds: 10);

  VideoPlayerController? _videoController;
  PlaybackSource? _source;
  VideoQuality? _currentQuality;
  double _playbackSpeed = 1.0;
  bool _isFullscreen = false;
  PlayerLoadStatus _status = PlayerLoadStatus.loading;
  String? _errorMessage;
  Timer? _progressTimer;

  VideoPlayerController? get videoController => _videoController;
  List<VideoQuality> get availableQualities => _source?.qualities ?? const [];
  VideoQuality? get currentQuality => _currentQuality;
  double get playbackSpeed => _playbackSpeed;
  bool get isFullscreen => _isFullscreen;
  PlayerLoadStatus get status => _status;
  String? get errorMessage => _errorMessage;

  bool get isPlaying => _videoController?.value.isPlaying ?? false;
  Duration get position => _videoController?.value.position ?? Duration.zero;
  Duration get duration => _videoController?.value.duration ?? Duration.zero;

  Future<void> initialize() async {
    _status = PlayerLoadStatus.loading;
    notifyListeners();

    try {
      final source = await _repository.getPlaybackSource(videoId);
      _source = source;
      await _loadQuality(
        source.defaultQuality,
        startAt: Duration(seconds: source.resumePositionSeconds),
      );
      _status = PlayerLoadStatus.ready;
      _startProgressTimer();
      await WakelockPlus.enable();
    } catch (e) {
      _status = PlayerLoadStatus.error;
      _errorMessage = e.toString();
    }
    notifyListeners();
  }

  Future<void> _loadQuality(VideoQuality quality, {Duration? startAt}) async {
    final resumeAt = startAt ?? position;
    final wasPlaying = isPlaying;

    final old = _videoController;
    final newController = VideoPlayerController.networkUrl(Uri.parse(quality.url));
    await newController.initialize();
    await newController.seekTo(resumeAt);
    await newController.setPlaybackSpeed(_playbackSpeed);

    _videoController = newController;
    _currentQuality = quality;
    newController.addListener(_onVideoTick);

    if (wasPlaying) {
      await newController.play();
    }

    await old?.pause();
    old?.removeListener(_onVideoTick);
    await old?.dispose();

    notifyListeners();
  }

  Future<void> switchQuality(VideoQuality quality) async {
    if (quality.label == _currentQuality?.label) return;
    await _loadQuality(quality);
  }

  Future<void> setPlaybackSpeed(double speed) async {
    _playbackSpeed = speed;
    await _videoController?.setPlaybackSpeed(speed);
    notifyListeners();
  }

  Future<void> togglePlayPause() async {
    final controller = _videoController;
    if (controller == null) return;

    if (controller.value.isPlaying) {
      await controller.pause();
      await _syncProgress();
    } else {
      await controller.play();
    }
    notifyListeners();
  }

  Future<void> seekTo(Duration position) async {
    await _videoController?.seekTo(position);
    notifyListeners();
  }

  Future<void> enterFullscreen() async {
    _isFullscreen = true;
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    notifyListeners();
  }

  Future<void> exitFullscreen() async {
    _isFullscreen = false;
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
    ]);
    notifyListeners();
  }

  Future<void> toggleFullscreen() =>
      _isFullscreen ? exitFullscreen() : enterFullscreen();

  void _onVideoTick() {
    final controller = _videoController;
    if (controller == null) return;

    // Auto-mark complete once within 2s of the end (HLS duration probing
    // can be a touch short of the true end).
    final value = controller.value;
    if (value.duration.inSeconds > 0 &&
        value.position.inSeconds >= value.duration.inSeconds - 2 &&
        value.isPlaying == false) {
      _syncProgress(completed: true);
    }
    notifyListeners();
  }

  void _startProgressTimer() {
    _progressTimer?.cancel();
    _progressTimer = Timer.periodic(_progressSyncInterval, (_) {
      if (isPlaying) _syncProgress();
    });
  }

  Future<void> _syncProgress({bool completed = false}) async {
    final controller = _videoController;
    if (controller == null || !controller.value.isInitialized) return;

    await _repository.updateWatchProgress(
      videoId: videoId,
      progressSeconds: controller.value.position.inSeconds,
      durationSeconds: controller.value.duration.inSeconds,
      completed: completed,
    );
  }

  @override
  void dispose() {
    _progressTimer?.cancel();
    _syncProgress();
    _videoController?.removeListener(_onVideoTick);
    _videoController?.dispose();
    WakelockPlus.disable();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    super.dispose();
  }
}
