import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/access_state.dart';

/// Reads the caller's role + access window (profiles.role,
/// access_started_at, access_expires_at) and the global pop-up config
/// (app_config) in two light queries.
class AccessRemoteDataSource {
  final SupabaseClient _client;

  AccessRemoteDataSource(this._client);

  Future<AccessState> fetch() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return AccessState.empty;

    final profile = await _client
        .from('profiles')
        .select('role, access_started_at, access_expires_at')
        .eq('id', userId)
        .maybeSingle();

    Map<String, dynamic>? config;
    try {
      config = await _client
          .from('app_config')
          .select(
            'popup_enabled, popup_start_at, popup_title, popup_body, popup_image_url',
          )
          .maybeSingle();
    } catch (_) {
      // Config table optional / unreachable — treat as no pop-up.
      config = null;
    }

    DateTime? parse(dynamic v) =>
        v == null ? null : DateTime.tryParse(v as String)?.toLocal();

    return AccessState(
      role: profile?['role'] as String?,
      accessStartedAt: parse(profile?['access_started_at']),
      expiresAt: parse(profile?['access_expires_at']),
      popupEnabled: (config?['popup_enabled'] as bool?) ?? false,
      popupStartAt: parse(config?['popup_start_at']),
      popupTitle: config?['popup_title'] as String?,
      popupBody: config?['popup_body'] as String?,
      popupImageUrl: config?['popup_image_url'] as String?,
    );
  }
}
