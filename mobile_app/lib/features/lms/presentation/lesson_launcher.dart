import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/purchase_config.dart';
import '../../audio/application/audio_providers.dart';
import '../../audio/domain/entities/audio_track.dart';
import '../application/lms_providers.dart';
import '../domain/entities/lesson.dart';

/// Opens a lesson — the single place that knows how each type is played.
///
/// This exists because there are now two entry points: the curriculum on
/// the course screen, and the resume card on Home. Three lesson types,
/// each with its own route and its own idea of what "done" means, is
/// exactly the logic that drifts when it is written twice — and the two
/// copies would disagree silently, since nothing fails when one of them
/// forgets to record progress.
///
/// It does NOT check ownership. The caller knows whether the lesson is
/// locked: the course screen has the purchase state, and the resume card
/// only ever points at a lesson this user has already opened. If access
/// has lapsed since, playback fails server-side — `issue-audio-license`
/// re-checks entitlement and will not mint a URL — which is the correct
/// place for that decision, and it surfaces here as an error message
/// rather than as silence.
Future<void> launchLesson(
  BuildContext context,
  WidgetRef ref,
  Lesson lesson, {
  /// Called after progress changes, so a screen showing progress can
  /// refresh. Home does not need it; the course screen does.
  VoidCallback? onProgressChanged,
}) async {
  if (!lesson.isPlayable) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("This $kPartWord's content isn't available right now."),
      ),
    );
    return;
  }

  // Stamp "you were here" before branching on type. Not awaited: it feeds
  // the resume card, and a card being a little stale is not worth a
  // moment between a tap and the lesson opening.
  unawaited(_recordAccess(ref, lesson));

  Future<void> markComplete() async {
    if (lesson.completed) return;
    try {
      await ref.read(lmsRepositoryProvider).markLessonCompleted(lesson.id);
      ref.invalidate(continueCourseProvider);
      onProgressChanged?.call();
    } catch (e) {
      // A progress write failing is not worth an error over content that
      // opened perfectly well.
      debugPrint('markLessonCompleted: $e');
    }
  }

  switch (lesson.type) {
    case LessonType.text:
      context.push('/lesson-text/${lesson.id}', extra: lesson);
      // Reading is the whole interaction for a text lesson, so opening
      // it counts as completing it.
      await markComplete();
      return;

    case LessonType.video:
      // Unlike a text lesson, opening the player proves nothing — the
      // stream can still fail. The player reports back whether it
      // actually played, and only then does this count as complete.
      final played = await context.push<bool>(
        '/lesson-video/${lesson.id}',
        extra: lesson,
      );
      if (played == true) await markComplete();
      return;

    case LessonType.audio:
      try {
        // Note the id passed is the AUDIO's id, not the lesson's —
        // that's what issue-audio-license is keyed on.
        await ref.read(audioHandlerProvider).playSingleTrack(AudioTrack(
              id: lesson.audioId!,
              title: lesson.audioTitle ?? lesson.title,
              artist: lesson.audioArtist,
              coverArtUrl: lesson.audioCoverArtUrl,
              durationSeconds: lesson.audioDurationSeconds,
            ));
        if (context.mounted) context.push('/now-playing');
        await markComplete();
      } catch (e) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
  }
}

Future<void> _recordAccess(WidgetRef ref, Lesson lesson) async {
  try {
    await ref.read(lmsRepositoryProvider).recordLessonAccess(lesson.id);
    ref.invalidate(continueCourseProvider);
  } catch (e) {
    debugPrint('recordLessonAccess: $e');
  }
}
