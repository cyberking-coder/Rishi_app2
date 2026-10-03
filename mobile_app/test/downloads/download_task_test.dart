import 'package:flutter_test/flutter_test.dart';
import 'package:meditation_app/features/downloads/domain/entities/download_content_type.dart';
import 'package:meditation_app/features/downloads/domain/entities/download_status.dart';
import 'package:meditation_app/features/downloads/domain/entities/download_task.dart';

void main() {
  group('DownloadStatus getters', () {
    test('isActive / isResumable / isPlayable', () {
      expect(DownloadStatus.downloading.isActive, isTrue);
      expect(DownloadStatus.paused.isResumable, isTrue);
      expect(DownloadStatus.failed.isResumable, isTrue);
      expect(DownloadStatus.completed.isPlayable, isTrue);
      expect(DownloadStatus.queued.isPlayable, isFalse);
      expect(DownloadStatus.revoked.isResumable, isFalse);
    });
    test('labels', () {
      expect(DownloadStatus.completed.label, 'Downloaded');
      expect(DownloadStatus.revoked.label, 'Unavailable');
    });
  });

  group('DownloadContentType', () {
    test('mime + wire round trip', () {
      expect(DownloadContentType.audio.mimeType, 'audio/mpeg');
      expect(DownloadContentType.video.mimeType, 'video/mp4');
      expect(DownloadContentType.fromWire('audio'), DownloadContentType.audio);
      expect(DownloadContentType.fromWire('video'), DownloadContentType.video);
    });
  });

  group('DownloadTask.progress', () {
    DownloadTask t({int? total, int received = 0}) => DownloadTask(
          id: 'i',
          contentId: 'c',
          contentType: DownloadContentType.audio,
          title: 't',
          status: DownloadStatus.downloading,
          receivedBytes: received,
          createdAt: DateTime(2026),
          totalBytes: total,
        );

    test('is zero when total unknown or zero (no divide-by-zero)', () {
      expect(t(total: null, received: 100).progress, 0);
      expect(t(total: 0, received: 100).progress, 0);
    });
    test('clamps to 0..1', () {
      expect(t(total: 100, received: 50).progress, 0.5);
      expect(t(total: 100, received: 200).progress, 1.0);
    });
  });

  group('DownloadTask JSON round-trip', () {
    test('toJson/fromJson preserves fields', () {
      final original = DownloadTask(
        id: 'audio_x_1',
        contentId: 'x',
        contentType: DownloadContentType.audio,
        title: 'Chakras',
        status: DownloadStatus.completed,
        receivedBytes: 1234,
        totalBytes: 1234,
        createdAt: DateTime.utc(2026, 1, 2, 3, 4, 5),
        licenseExpiresAt: DateTime.utc(2027, 1, 1),
      );
      final restored = DownloadTask.fromJson(original.toJson());
      expect(restored.id, original.id);
      expect(restored.contentType, DownloadContentType.audio);
      expect(restored.status, DownloadStatus.completed);
      expect(restored.receivedBytes, 1234);
      expect(restored.licenseExpiresAt, original.licenseExpiresAt);
    });

    test('missing optional fields default safely', () {
      final restored = DownloadTask.fromJson({
        'id': 'i',
        'content_id': 'c',
        'content_type': 'audio',
        'title': 't',
        'status': 'queued',
        'created_at': DateTime.utc(2026).toIso8601String(),
      });
      expect(restored.receivedBytes, 0);
      expect(restored.totalBytes, isNull);
      expect(restored.licenseExpiresAt, isNull);
    });
  });

  group('isLicenseExpired', () {
    DownloadTask withExpiry(DateTime? e) => DownloadTask(
          id: 'i',
          contentId: 'c',
          contentType: DownloadContentType.audio,
          title: 't',
          status: DownloadStatus.completed,
          receivedBytes: 0,
          createdAt: DateTime(2026),
          licenseExpiresAt: e,
        );
    test('null never expires; past is expired; future is not', () {
      expect(withExpiry(null).isLicenseExpired, isFalse);
      expect(withExpiry(DateTime(2000)).isLicenseExpired, isTrue);
      expect(withExpiry(DateTime.now().add(const Duration(days: 1)))
          .isLicenseExpired, isFalse);
    });
  });
}
