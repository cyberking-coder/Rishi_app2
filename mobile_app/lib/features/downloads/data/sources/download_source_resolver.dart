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
    // Test-mode fast path: audio with a direct public URL downloads
    // straight from that URL, bypassing the R2 signing pipeline.
    if (type == DownloadContentType.audio) {
      final row = await _client
          .from('audios')
          .select('direct_url')
          .eq('id', contentId)
          .maybeSingle();
      final directUrl = row?['direct_url'] as String?;
      if (directUrl != null && directUrl.isNotEmpty) {
        return Uri.parse(directUrl);
      }
    }

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
    final String? urlString = switch (type) {
      // Videos return a quality ladder; download the first (default) one.
      DownloadContentType.video => () {
          final qualities = data['qualities'] as List?;
          if (qualities == null || qualities.isEmpty) return null;
          return (qualities.first as Map)['url'] as String?;
        }(),
      DownloadContentType.audio => data['url'] as String?,
    };
    if (urlString == null || urlString.isEmpty) {
      throw AuthFailure.unknown('Download source unavailable');
    }
    final uri = Uri.tryParse(urlString);
    if (uri == null) throw AuthFailure.unknown('Invalid download URL');
    return uri;
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

  /// Returns the set of contentIds whose download the CURRENT active device
  /// should purge locally — i.e. revoked/expired server-side and NOT still
  /// held as a valid ('ready') download by this device.
  ///
  /// This used to filter on `user_id` alone, which is what deleted people's
  /// downloads on restart. A "Reset device" / "Reset All Devices" (routine
  /// in this app, because of the one-device lock) sets that device's
  /// download rows to 'revoked'. The user re-registers on the SAME phone and
  /// their files are still on disk — but a user-scoped query returned the
  /// revoked content and the launch purge wiped it, even though the device
  /// was active again and the account still had access.
  ///
  /// Two guards fix that:
  ///   1. If there is no active device (offline, or the window between a
  ///      reset and the next login), return nothing and skip the purge
  ///      entirely — deleting then would wipe a device that is simply not
  ///      the currently-registered one, and next launch can try again.
  ///   2. Never purge content this device still has a 'ready' row for. A
  ///      revoked row left behind by an OLD device must not delete the copy
  ///      this device legitimately re-downloaded.
  Future<Set<String>> revokedContentIds() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return {};

    String activeDeviceId;
    try {
      activeDeviceId = await _getActiveDeviceId();
    } catch (_) {
      // No active device right now — do not delete anything.
      return {};
    }

    final rows = await _client
        .from('downloads')
        .select('video_id, audio_id, device_id, download_status')
        .eq('user_id', userId);

    final readyOnThisDevice = <String>{};
    final revoked = <String>{};
    for (final row in rows as List) {
      final id = (row['video_id'] ?? row['audio_id']) as String?;
      if (id == null) continue;
      final status = row['download_status'] as String?;
      if (status == 'ready' && row['device_id'] == activeDeviceId) {
        readyOnThisDevice.add(id);
      } else if (status == 'revoked' || status == 'expired') {
        revoked.add(id);
      }
    }
    // A copy the active device still holds a valid entitlement for is never
    // purged, whatever a different device's row says.
    return revoked.difference(readyOnThisDevice);
  }
}
