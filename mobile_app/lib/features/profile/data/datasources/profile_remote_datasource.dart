import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/errors/auth_failure.dart';

class ProfileRemoteDataSource {
  final SupabaseClient _client;

  ProfileRemoteDataSource(this._client);

  Future<Map<String, dynamic>> getProfileRow() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw AuthFailure.unknown('Not logged in');

    final row =
        await _client.from('profiles').select().eq('id', userId).single();
    return row;
  }

  /// Most recent subscription row regardless of status, ordered newest
  /// first, so a canceled/expired plan still shows in the UI instead of
  /// silently falling back to "free".
  Future<Map<String, dynamic>?> getLatestSubscriptionRow() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw AuthFailure.unknown('Not logged in');

    final rows = await _client
        .from('subscriptions')
        .select('status, current_period_end, cancel_at_period_end, '
            'subscription_plans(name)')
        .eq('user_id', userId)
        .order('created_at', ascending: false)
        .limit(1);

    return (rows as List).isEmpty ? null : rows.first as Map<String, dynamic>;
  }

  Future<List<Map<String, dynamic>>> getDeviceRows() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw AuthFailure.unknown('Not logged in');

    final rows = await _client
        .from('devices')
        .select()
        .eq('user_id', userId)
        .order('last_seen_at', ascending: false);
    return (rows as List).cast<Map<String, dynamic>>();
  }
}
