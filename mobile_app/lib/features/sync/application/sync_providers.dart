import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/supabase_client_provider.dart';
import '../../lms/application/lms_providers.dart';
import '../data/pending_sync_store.dart';

/// The one shared offline-action queue. Overridden in main.dart with the same
/// instance handed to the audio handler, so progress saved by the handler and
/// progress replayed here go through a single store.
final pendingSyncStoreProvider = Provider<PendingSyncStore>((_) {
  return PendingSyncStore();
});

/// Replays queued offline actions to the server. Call [flush] when the app
/// comes online (the access controller does this on every online resolve).
class SyncService {
  SyncService(this._ref);
  final Ref _ref;
  bool _flushing = false;

  Future<void> flush() async {
    if (_flushing) return;
    _flushing = true;
    try {
      final store = _ref.read(pendingSyncStoreProvider);
      final pending = await store.read();
      if (pending.isEmpty) return;

      final client = _ref.read(supabaseClientProvider);
      for (final e in pending.watch.values.toList()) {
        try {
          await client.rpc('upsert_watch_progress', params: {
            'p_video_id': null,
            'p_audio_id': e.audioId,
            'p_progress_seconds': e.progressSeconds,
            'p_duration_seconds': e.durationSeconds,
            'p_completed': e.completed,
          });
          await store.update((p) => p.withoutWatch(e.audioId));
        } catch (_) {
          // Network again / server busy — keep it for the next flush.
        }
      }

      final lms = _ref.read(lmsRepositoryProvider);
      for (final id in pending.completedLessons.toList()) {
        try {
          await lms.markLessonCompleted(id);
          await store.update((p) => p.withoutLesson(id));
        } catch (_) {
          // Keep for retry.
        }
      }
    } finally {
      _flushing = false;
    }
  }
}

final syncServiceProvider = Provider<SyncService>((ref) => SyncService(ref));
