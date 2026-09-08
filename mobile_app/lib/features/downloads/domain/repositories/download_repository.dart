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

  /// Deletes every downloaded file and manifest entry. Called on LOGOUT, so
  /// the next user never inherits the previous user's offline files.
  Future<void> purgeAll();

  /// Purges only PREMIUM downloads, keeping free ones. Called when the
  /// user's access window lapses: free content never required access, so
  /// deleting it on expiry is wrong. Best-effort — if it cannot determine
  /// which downloads are premium (offline), it deletes nothing and retries
  /// on the next launch.
  Future<void> purgePremiumDownloads();

  /// Human-readable snapshot of the download storage state, shown on the
  /// empty Downloads screen so a persistence/purge fault can be diagnosed on
  /// the device without a computer.
  Future<String> debugSummary();

  Future<void> dispose();
}
