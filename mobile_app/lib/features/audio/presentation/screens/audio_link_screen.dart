import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_theme.dart';
import '../../application/audio_providers.dart';

/// Where `/audio/:id` lands — the destination of a "start your day"
/// notification.
///
/// Its whole job is to turn an id into a playing track and get out of the
/// way. It resolves the track, starts it, and replaces itself with Now
/// Playing, so the back button goes wherever the user was rather than to
/// a loading screen they'd have to escape twice.
class AudioLinkScreen extends ConsumerStatefulWidget {
  final String audioId;

  const AudioLinkScreen({super.key, required this.audioId});

  @override
  ConsumerState<AudioLinkScreen> createState() => _AudioLinkScreenState();
}

class _AudioLinkScreenState extends ConsumerState<AudioLinkScreen> {
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _open());
  }

  Future<void> _open() async {
    try {
      final track =
          await ref.read(audioRepositoryProvider).getTrack(widget.audioId);

      if (track == null) {
        // Unpublished, archived or deleted between the notification going
        // out and being tapped. Say so plainly rather than showing a
        // player that will fail a moment later.
        if (mounted) {
          setState(() => _error = 'This meditation is no longer available.');
        }
        return;
      }

      await ref.read(audioHandlerProvider).playSingleTrack(track);
      if (mounted) context.pushReplacement('/now-playing');
    } catch (e) {
      if (mounted) setState(() => _error = 'Could not start playback.\n$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: _error == null
              ? const Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(
                        color: AppTheme.sage, strokeWidth: 2),
                    SizedBox(height: 16),
                    Text(
                      'Starting your meditation…',
                      style:
                          TextStyle(fontSize: 14, color: AppTheme.textSecondary),
                    ),
                  ],
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          color: AppTheme.textSecondary, height: 1.5),
                    ),
                    const SizedBox(height: 20),
                    FilledButton(
                      onPressed: () => context.go('/home'),
                      child: const Text('Go to Home'),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
