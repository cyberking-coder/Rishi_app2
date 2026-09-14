import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/supabase_client_provider.dart';
import '../data/live_sessions_datasource.dart';
import '../domain/entities/live_session.dart';

final liveSessionsDataSourceProvider = Provider<LiveSessionsDataSource>((ref) {
  return LiveSessionsDataSource(ref.watch(supabaseClientProvider));
});

final upcomingSessionsProvider =
    FutureProvider.autoDispose<List<LiveSession>>((ref) {
  return ref.watch(liveSessionsDataSourceProvider).getUpcoming();
});

/// Sessions this user has paid for.
///
/// Separate from [upcomingSessionsProvider] rather than folded into it,
/// so returning from checkout can refresh just this — the session list
/// itself has not changed, only what this person may do with it.
final paidSessionsProvider = FutureProvider.autoDispose<Set<String>>((ref) {
  return ref.watch(liveSessionsDataSourceProvider).getPaidRegistrations();
});
