import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

import '../domain/entities/audio_track.dart';
import '../domain/repositories/audio_repository.dart';

const List<double> kAvailableAudioSpeeds = [0.75, 1.0, 1.25, 1.5, 1.75, 2.0];

/// The audio_service backend: this is what keeps audio playing while the
/// app is backgrounded, drives the OS media notification, and owns the
/// just_audio player. Built once at app startup (see main.dart) rather
/// than per-screen, since the OS notification must survive navigation.
class AudioPlayerHandler extends BaseAudioHandler
    with QueueHandler, SeekHandler {
  final AudioRepository _repository;
  final AudioPlayer _player = AudioPlayer();

  List<AudioTrack> _tracks = [];
  int _currentIndex = -1;
  Timer? _progressTimer;
  Timer? _sleepTimer;

  /// Null when no sleep timer is set; counts down while one is active.
  final ValueNotifier<Duration?> sleepTimerRemaining = ValueNotifier(null);

  AudioPlayerHandler(this._repository) {
    _player.playbackEventStream.listen(
      _broadcastState,
      onError: (Object e, StackTrace st) {
        playbackState.add(playbackState.value.copyWith(
          processingState: AudioProcessingState.error,
        ));
      },
    );

    _player.processingStateStream.listen((state) {
      if (state == ProcessingState.completed) {
        _flushProgress(completed: true);
        skipToNext();
      }
    });
  }

  /// Convenience for "play now" taps (a single audio card, or a
  /// continue-listening item) -- just a one-track playlist.
  Future<void> playSingleTrack(AudioTrack track) => loadPlaylist([track]);

  AudioTrack? get currentTrack =>
      _currentIndex >= 0 && _currentIndex < _tracks.length
          ? _tracks[_currentIndex]
          : null;

  /// Loads a queue of tracks (a playlist, or a single track for "play
  /// now" / continue-listening) and starts playback at [startIndex].
  Future<void> loadPlaylist(
    List<AudioTrack> tracks, {
    int startIndex = 0,
  }) async {
    _tracks = tracks;
    queue.add(tracks.map(_toMediaItem).toList());
    await _playIndex(startIndex);
  }

  Future<void> _playIndex(int index, {Duration? resumeAt}) async {
    if (index < 0 || index >= _tracks.length) {
      await stop();
      return;
    }

    await _flushProgress();

    _currentIndex = index;
    final track = _tracks[index];
    mediaItem.add(_toMediaItem(track));
    playbackState.add(playbackState.value.copyWith(
      processingState: AudioProcessingState.loading,
      queueIndex: index,
    ));

    final source = await _repository.getPlaybackSource(track.id);
    await _player.setAudioSource(AudioSource.uri(Uri.parse(source.url)));
    await _player.seek(resumeAt ?? Duration(seconds: source.resumePositionSeconds));
    await _player.play();

    _startProgressTimer();
  }

  MediaItem _toMediaItem(AudioTrack track) => MediaItem(
        id: track.id,
        title: track.title,
        artist: track.artist,
        artUri: track.coverArtUrl != null ? Uri.parse(track.coverArtUrl!) : null,
        duration: track.durationSeconds != null
            ? Duration(seconds: track.durationSeconds!)
            : null,
      );

  @override
  Future<void> play() => _player.play();

  @override
  Future<void> pause() async {
    await _player.pause();
    await _flushProgress();
  }

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> skipToNext() => _playIndex(_currentIndex + 1);

  @override
  Future<void> skipToPrevious() => _playIndex(_currentIndex - 1);

  @override
  Future<void> skipToQueueItem(int index) => _playIndex(index);

  @override
  Future<void> stop() async {
    _progressTimer?.cancel();
    _sleepTimer?.cancel();
    await _flushProgress();
    await _player.stop();
    playbackState.add(playbackState.value.copyWith(
      processingState: AudioProcessingState.idle,
    ));
    return super.stop();
  }

  Future<void> setSpeed(double speed) async {
    await _player.setSpeed(speed);
    playbackState.add(playbackState.value.copyWith(speed: speed));
  }

  double get speed => _player.speed;

  /// Continuously-ticking position stream (~every 200ms while playing) so
  /// the UI progress bar advances smoothly, rather than only on discrete
  /// playback events. The OS-facing playbackState stays event-driven.
  Stream<Duration> get positionStream => _player.positionStream;

  /// The player's actual loaded duration (authoritative over the
  /// metadata duration, which may be wrong/estimated).
  Stream<Duration?> get durationStream => _player.durationStream;
  Duration? get currentDuration => _player.duration;

  /// Pauses playback once [duration] elapses. Pass null to cancel an
  /// active timer. Ticks [sleepTimerRemaining] every second so the UI can
  /// show a live countdown.
  void setSleepTimer(Duration? duration) {
    _sleepTimer?.cancel();
    sleepTimerRemaining.value = duration;

    if (duration == null) return;

    var remaining = duration;
    _sleepTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      remaining -= const Duration(seconds: 1);
      if (remaining <= Duration.zero) {
        timer.cancel();
        sleepTimerRemaining.value = null;
        pause();
      } else {
        sleepTimerRemaining.value = remaining;
      }
    });
  }

  void _startProgressTimer() {
    _progressTimer?.cancel();
    _progressTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (_player.playing) _flushProgress();
    });
  }

  Future<void> _flushProgress({bool completed = false}) async {
    final track = currentTrack;
    if (track == null || !_player.duration.isPresent) return;

    try {
      await _repository.updateListenProgress(
        audioId: track.id,
        progressSeconds: _player.position.inSeconds,
        durationSeconds: _player.duration?.inSeconds ?? 0,
        completed: completed,
      );
    } catch (e) {
      // Network may be unavailable (offline playback). Progress save is
      // best-effort — never block or crash playback over it.
      debugPrint('_flushProgress: $e');
    }
  }

  void _broadcastState(PlaybackEvent event) {
    final playing = _player.playing;
    playbackState.add(playbackState.value.copyWith(
      controls: [
        MediaControl.skipToPrevious,
        if (playing) MediaControl.pause else MediaControl.play,
        MediaControl.skipToNext,
        MediaControl.stop,
      ],
      systemActions: const {
        MediaAction.seek,
        MediaAction.seekForward,
        MediaAction.seekBackward,
      },
      androidCompactActionIndices: const [0, 1, 2],
      processingState: const {
        ProcessingState.idle: AudioProcessingState.idle,
        ProcessingState.loading: AudioProcessingState.loading,
        ProcessingState.buffering: AudioProcessingState.buffering,
        ProcessingState.ready: AudioProcessingState.ready,
        ProcessingState.completed: AudioProcessingState.completed,
      }[_player.processingState]!,
      playing: playing,
      updatePosition: _player.position,
      speed: _player.speed,
      queueIndex: _currentIndex,
    ));
  }

  @override
  Future<void> onTaskRemoved() async {
    await stop();
  }
}

extension on Duration? {
  bool get isPresent => this != null;
}
