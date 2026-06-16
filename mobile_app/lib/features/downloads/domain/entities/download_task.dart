import 'download_content_type.dart';
import 'download_status.dart';

/// A single offline download. This is the persisted unit of work: its
/// metadata lives in the local manifest, its encrypted bytes in the app
/// sandbox, and its encryption key in the OS keystore (keyed by [id]).
///
/// Note: the AES key/IV are deliberately NOT fields here — they never sit
/// in plaintext metadata. They are fetched from secure storage only at the
/// moment of encrypt/decrypt.
class DownloadTask {
  /// Stable id == the download id; also the secure-storage key namespace
  /// and the encrypted file name (`<id>.enc`).
  final String id;

  /// The video/audio id this download corresponds to (for license + UI).
  final String contentId;
  final DownloadContentType contentType;
  final String title;
  final String? thumbnailUrl;

  /// Total plaintext bytes (== encrypted size; CTR is length-preserving).
  /// Null until the first byte/Content-Range is seen.
  final int? totalBytes;
  final int receivedBytes;
  final DownloadStatus status;

  /// When the offline license expires; after this the file must be purged.
  final DateTime? licenseExpiresAt;
  final DateTime createdAt;
  final String? errorMessage;

  const DownloadTask({
    required this.id,
    required this.contentId,
    required this.contentType,
    required this.title,
    required this.status,
    required this.receivedBytes,
    required this.createdAt,
    this.thumbnailUrl,
    this.totalBytes,
    this.licenseExpiresAt,
    this.errorMessage,
  });

  double get progress {
    final total = totalBytes;
    if (total == null || total == 0) return 0;
    return (receivedBytes / total).clamp(0.0, 1.0);
  }

  bool get isLicenseExpired =>
      licenseExpiresAt != null && DateTime.now().isAfter(licenseExpiresAt!);

  DownloadTask copyWith({
    int? totalBytes,
    int? receivedBytes,
    DownloadStatus? status,
    DateTime? licenseExpiresAt,
    String? errorMessage,
    bool clearError = false,
  }) {
    return DownloadTask(
      id: id,
      contentId: contentId,
      contentType: contentType,
      title: title,
      thumbnailUrl: thumbnailUrl,
      totalBytes: totalBytes ?? this.totalBytes,
      receivedBytes: receivedBytes ?? this.receivedBytes,
      status: status ?? this.status,
      licenseExpiresAt: licenseExpiresAt ?? this.licenseExpiresAt,
      createdAt: createdAt,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'content_id': contentId,
        'content_type': contentType.wireName,
        'title': title,
        'thumbnail_url': thumbnailUrl,
        'total_bytes': totalBytes,
        'received_bytes': receivedBytes,
        'status': status.name,
        'license_expires_at': licenseExpiresAt?.toIso8601String(),
        'created_at': createdAt.toIso8601String(),
        'error_message': errorMessage,
      };

  factory DownloadTask.fromJson(Map<String, dynamic> json) => DownloadTask(
        id: json['id'] as String,
        contentId: json['content_id'] as String,
        contentType: DownloadContentType.fromWire(json['content_type'] as String),
        title: json['title'] as String,
        thumbnailUrl: json['thumbnail_url'] as String?,
        totalBytes: json['total_bytes'] as int?,
        receivedBytes: json['received_bytes'] as int? ?? 0,
        status: DownloadStatus.values.byName(json['status'] as String),
        licenseExpiresAt: json['license_expires_at'] == null
            ? null
            : DateTime.parse(json['license_expires_at'] as String),
        createdAt: DateTime.parse(json['created_at'] as String),
        errorMessage: json['error_message'] as String?,
      );
}
