/// Lifecycle of a single offline download.
enum DownloadStatus {
  /// Queued but not yet started (no bytes written).
  queued,

  /// Actively transferring + encrypting bytes.
  downloading,

  /// User-paused; partial encrypted file is on disk, resumable.
  paused,

  /// Fully downloaded, encrypted, and playable offline.
  completed,

  /// Transfer aborted by an error; resumable from the last byte.
  failed,

  /// License pulled server-side (e.g. device swap / sub cancelled).
  /// Local bytes must be purged.
  revoked,
}

extension DownloadStatusX on DownloadStatus {
  bool get isActive => this == DownloadStatus.downloading;
  bool get isResumable =>
      this == DownloadStatus.paused || this == DownloadStatus.failed;
  bool get isPlayable => this == DownloadStatus.completed;

  String get label => switch (this) {
        DownloadStatus.queued => 'Queued',
        DownloadStatus.downloading => 'Downloading',
        DownloadStatus.paused => 'Paused',
        DownloadStatus.completed => 'Downloaded',
        DownloadStatus.failed => 'Failed',
        DownloadStatus.revoked => 'Unavailable',
      };
}
