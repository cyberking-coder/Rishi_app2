import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../domain/pending_sync.dart';

/// Durable, on-device queue of offline actions (listen progress, lesson
/// completions) awaiting replay to the server. A plain JSON file — it holds
/// no secret, and a decrypt hiccup must never lose a user's progress silently.
///
/// Serialised access: every mutation reads the file, applies a pure change,
/// and writes it back behind a single-slot lock so concurrent progress saves
/// can't clobber each other.
class PendingSyncStore {
  File? _file;
  Future<void> _lock = Future.value();

  Future<File> _f() async {
    if (_file != null) return _file!;
    final dir = await getApplicationSupportDirectory();
    _file = File('${dir.path}/pending_sync.json');
    return _file!;
  }

  Future<PendingSync> read() async {
    try {
      final f = await _f();
      if (!await f.exists()) return const PendingSync();
      final raw = await f.readAsString();
      if (raw.trim().isEmpty) return const PendingSync();
      return PendingSync.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return const PendingSync();
    }
  }

  Future<void> _write(PendingSync p) async {
    try {
      final f = await _f();
      await f.writeAsString(jsonEncode(p.toJson()), flush: true);
    } catch (_) {
      // Best-effort; a failed write just means this event may not survive a
      // cold start. The online path still tried to send it.
    }
  }

  /// Applies [change] to the current queue atomically (serialised).
  Future<void> update(PendingSync Function(PendingSync) change) {
    final next = _lock.then((_) async {
      final current = await read();
      await _write(change(current));
    });
    // Keep the chain alive even if one step throws.
    _lock = next.catchError((_) {});
    return next;
  }

  Future<void> enqueueWatchProgress(WatchProgressEvent e) =>
      update((p) => p.withWatch(e));

  Future<void> enqueueLessonCompleted(String lessonId) =>
      update((p) => p.withLessonCompleted(lessonId));
}
