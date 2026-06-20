import '../entities/download_content_type.dart';
import '../entities/download_task.dart';

/// Contract for the offline-download subsystem. The presentation layer
/// only ever talks to this — it never touches files, crypto, or sockets.
abstract class DownloadRepository {
  /// Broadcasts the full task list on every state change (progress,
  /// status transitions, additions, removals).
  Stream<List<DownloadTask>> watchTasks();

  /// Current snapshot of all tasks.
  List<DownloadTask> get tasks;

  /// Loads persisted tasks from the local manifest and reconciles them
  /// (e.g. marks interrupted `downloading` tasks as `paused`). Call once
  /// at startup before using the manager.
  Future<void> restore();

  /// Enqueues and immediately starts a new download. Returns the task id.
  Future<String> enqueue({
    required String contentId,
    required DownloadContentType contentType,
    required String title,
    String? thumbnailUrl,
  });

  Future<void> pause(String downloadId);
  Future<void> resume(String downloadId);

  /// Deletes the encrypted file, its key, and the manifest entry.
  Future<void> delete(String downloadId);

  /// Whether [contentId] is fully downloaded and playable offline.
  bool isDownloaded(String contentId);

  /// Returns a loopback URL the player can hand to video_player/just_audio
  /// for offline playback. The proxy decrypts on the fly. Throws if the
  /// content isn't downloaded/playable.
  Future<Uri> localPlaybackUrl(String contentId);

  /// Purges any downloads whose server-side license was revoked or whose
  /// offline license has expired. Safe to call periodically / on launch.
  Future<void> purgeRevokedAndExpired();

  /// Deletes every downloaded file and manifest entry. Called when the
  /// user's retreat access window lapses.
  Future<void> purgeAll();

  Future<void> dispose();
}
