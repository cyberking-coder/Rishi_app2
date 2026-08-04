import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/access_state.dart';
import '../domain/entities/app_popup.dart';

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

    DateTime? parse(dynamic v) =>
        v == null ? null : DateTime.tryParse(v as String)?.toLocal();

    return AccessState(
      role: profile?['role'] as String?,
      accessStartedAt: parse(profile?['access_started_at']),
      expiresAt: parse(profile?['access_expires_at']),
      popups: await _fetchPopups(),
      registeredPopupIds: await _fetchRegistrations(userId),
    );
  }

  /// Workshops this user has already paid for.
  ///
  /// Read alongside the pop-ups so the card can say "You're registered"
  /// instead of offering to charge them a second time. RLS limits this to
  /// their own rows, so no filtering is needed beyond the status.
  Future<Set<String>> _fetchRegistrations(String userId) async {
    try {
      final rows = await _client
          .from('workshop_registrations')
          .select('popup_id')
          .eq('user_id', userId)
          .eq('status', 'paid');

      return {
        for (final row in rows as List) (row as Map)['popup_id'] as String,
      };
    } catch (_) {
      // Table absent (build newer than the database) or unreachable.
      // Treated as "not registered", which shows the button — the
      // checkout page and the webhook both refuse a second seat, so the
      // worst case is a wasted tap rather than a double charge.
      return const {};
    }
  }

  /// Every enabled pop-up, ordered as the admin arranged them.
  ///
  /// Falls back to the legacy single pop-up on app_config if app_popups
  /// isn't there — which is what an app build newer than the database
  /// would hit. Losing the pop-up entirely in that window would be a
  /// silent regression nobody would connect to a missing migration.
  Future<List<AppPopup>> _fetchPopups() async {
    try {
      final rows = await _client
          .from('app_popups')
          .select(
            'id, title, body, image_url, weekday, starts_at, sort_order, '
            'price_amount, currency, cta_label',
          )
          .eq('enabled', true)
          .order('sort_order', ascending: true);

      return [
        for (final row in rows as List)
          AppPopup.fromMap(Map<String, dynamic>.from(row as Map)),
      ];
    } catch (_) {
      return _fetchLegacyPopup();
    }
  }

  Future<List<AppPopup>> _fetchLegacyPopup() async {
    try {
      final config = await _client
          .from('app_config')
          .select(
            'popup_enabled, popup_start_at, popup_title, popup_body, '
            'popup_image_url',
          )
          .maybeSingle();

      if (config == null || config['popup_enabled'] != true) return const [];

      return [
        AppPopup(
          // A stable id, so the once-a-day guard has something to
          // remember it by. The legacy pop-up is a singleton, so a
          // constant is enough.
          id: 'legacy-app-config',
          title: config['popup_title'] as String?,
          body: config['popup_body'] as String?,
          imageUrl: config['popup_image_url'] as String?,
          startsAt: config['popup_start_at'] == null
              ? null
              : DateTime.tryParse(config['popup_start_at'] as String)
                  ?.toLocal(),
        ),
      ];
    } catch (_) {
      // Neither table reachable — treat as no pop-up rather than failing
      // the whole access fetch, which would also hide the user's content.
      return const [];
    }
  }
}
