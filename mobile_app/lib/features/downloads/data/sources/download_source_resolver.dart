import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/errors/auth_failure.dart';
import '../../domain/entities/download_content_type.dart';

/// Resolves a short-lived, signed Cloudflare-R2 URL to fetch the bytes for
/// a download. Reuses the same license edge functions as streaming, so
/// device-lock + entitlement checks are enforced identically. Because the
/// signed URL is short-lived, this is called fresh on every start/resume.
class DownloadSourceResolver {
  final SupabaseClient _client;

  DownloadSourceResolver(this._client);

  Future<Uri> resolve(String contentId, DownloadContentType type) async {
    final deviceId = await _getActiveDeviceId();

    final (fnName, bodyKey) = switch (type) {
      DownloadContentType.video => ('issue-playback-license', 'video_id'),
      DownloadContentType.audio => ('issue-audio-license', 'audio_id'),
    };

    final response = await _client.functions.invoke(
      fnName,
      body: {bodyKey: contentId},
      headers: {'X-Device-Id': deviceId},
    );

    if (response.status != 200) {
      if (response.status == 403) throw AuthFailure.deviceLocked();
      final error = (response.data is Map)
          ? (response.data['error'] as String? ?? 'Download unavailable')
          : 'Download unavailable';
      throw AuthFailure.unknown(error);
    }

    final data = response.data as Map<String, dynamic>;
    final urlString = switch (type) {
      // Videos return a quality ladder; download the first (default) one.
      DownloadContentType.video =>
        (data['qualities'] as List).first['url'] as String,
      DownloadContentType.audio => data['url'] as String,
    };
    return Uri.parse(urlString);
  }

  Future<String> _getActiveDeviceId() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw AuthFailure.unknown('Not logged in');

    final row = await _client
        .from('devices')
        .select('id')
        .eq('user_id', userId)
        .eq('is_active', true)
        .maybeSingle();

    if (row == null) throw AuthFailure.unknown('No active device registered');
    return row['id'] as String;
  }

  /// Marks a download row server-side so license/analytics stay in sync.
  /// Best-effort: failures here must not block the local download.
  ///
  /// The `downloads` uniqueness is enforced by *partial* unique indexes
  /// (`where video_id is not null` / `where audio_id is not null`), which
  /// PostgREST's `onConflict` upsert cannot target — so we check-then-write
  /// explicitly instead.
  Future<void> recordServerDownload({
    required String contentId,
    required DownloadContentType type,
  }) async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) return;
      final deviceId = await _getActiveDeviceId();
      final column =
          type == DownloadContentType.video ? 'video_id' : 'audio_id';

      final existing = await _client
          .from('downloads')
          .select('id')
          .eq('user_id', userId)
          .eq('device_id', deviceId)
          .eq(column, contentId)
          .maybeSingle();

      final values = {
        'download_status': 'ready',
        'downloaded_at': DateTime.now().toUtc().toIso8601String(),
      };

      if (existing == null) {
        await _client.from('downloads').insert({
          'user_id': userId,
          'device_id': deviceId,
          column: contentId,
          ...values,
        });
      } else {
        await _client
            .from('downloads')
            .update(values)
            .eq('id', existing['id'] as String);
      }
    } catch (_) {
      // Non-fatal: the local file is still usable offline.
    }
  }

  /// Returns the set of contentIds whose server-side download row is
  /// revoked/expired for the active device, so they can be purged locally.
  Future<Set<String>> revokedContentIds() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return {};

    final rows = await _client
        .from('downloads')
        .select('video_id, audio_id, download_status')
        .eq('user_id', userId)
        .inFilter('download_status', ['revoked', 'expired']);

    return {
      for (final row in rows as List)
        (row['video_id'] ?? row['audio_id']) as String,
    };
  }
}
