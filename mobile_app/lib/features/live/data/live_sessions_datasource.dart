import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/entities/live_session.dart';

class LiveSessionsDataSource {
  final SupabaseClient _client;

  LiveSessionsDataSource(this._client);

  /// Sessions worth showing: anything that hasn't finished yet.
  ///
  /// Filtered on starts_at rather than on the end time because the
  /// database doesn't store one — a session that overruns is normal, and
  /// a card that disappears mid-call would be worse than one that
  /// lingers. Three hours of slack covers any realistic session; the card
  /// itself greys out once its own end time passes.
  Future<List<LiveSession>> getUpcoming() async {
    final cutoff = DateTime.now().toUtc().subtract(const Duration(hours: 3));

    final rows = await _client
        .from('live_sessions')
        .select(
          'id, title, description, join_url, thumbnail_url, starts_at, '
          'duration_minutes, status, price_amount, currency, seat_limit',
        )
        .gte('starts_at', cutoff.toIso8601String())
        .order('starts_at', ascending: true);

    return [
      for (final row in rows as List)
        LiveSession.fromMap(Map<String, dynamic>.from(row as Map)),
    ];
  }

  /// Session ids this user has a paid seat at.
  ///
  /// RLS limits the read to their own rows, so there is nothing to filter
  /// beyond the status.
  Future<Set<String>> getPaidRegistrations() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return const {};

    final rows = await _client
        .from('workshop_registrations')
        .select('live_session_id')
        .eq('user_id', userId)
        .eq('status', 'paid');

    return {
      for (final row in rows as List)
        if ((row as Map)['live_session_id'] != null)
          row['live_session_id'] as String,
    };
  }

  /// The meeting link, if this user is entitled to it.
  ///
  /// Always fetched rather than read off the session row. A paid
  /// session's row carries an empty join_url by design — the real link
  /// lives in a table members cannot select, and this function is the one
  /// place that decides whether to hand it over. A free session returns
  /// its link unchanged, so the same call works for both and the screen
  /// never has to know which kind it is holding.
  Future<String?> getJoinUrl(String sessionId) async {
    final url = await _client.rpc(
      'live_session_join_url',
      params: {'p_session_id': sessionId},
    );
    final text = url as String?;
    return (text == null || text.isEmpty) ? null : text;
  }

  /// Records this device's FCM token so reminders can reach it.
  ///
  /// The table is keyed on the token, so a plain upsert is enough — no
  /// partial index in sight, unlike course_purchases. Re-registering the
  /// same token just refreshes last_seen_at, which is what tells a future
  /// cleanup which rows are dead weight.
  Future<void> registerPushToken({
    required String token,
    required String platform,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;

    await _client.from('push_tokens').upsert(
      {
        'token': token,
        'user_id': userId,
        'platform': platform,
        'last_seen_at': DateTime.now().toUtc().toIso8601String(),
      },
      onConflict: 'token',
    );
  }

  /// Called on sign-out. Leaving the row behind would keep pushing this
  /// user's reminders to a handset somebody else may now be holding.
  Future<void> unregisterPushToken(String token) async {
    await _client.from('push_tokens').delete().eq('token', token);
  }
}
