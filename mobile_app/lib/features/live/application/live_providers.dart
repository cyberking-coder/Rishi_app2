import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/supabase_client_provider.dart';
import '../../../core/push/push_service.dart';
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

/// Registers this device for reminders, once, after sign-in.
///
/// A provider rather than a call site so it can't be run twice from two
/// screens, and so the token-refresh subscription is torn down with the
/// scope rather than leaking. Kept alive deliberately — autoDispose would
/// cancel the refresh listener the moment no screen was watching, which
/// is most of the time.
final pushRegistrationProvider = Provider<void>((ref) {
  final dataSource = ref.watch(liveSessionsDataSourceProvider);

  Future<void> register(String token) async {
    try {
      await dataSource.registerPushToken(
        token: token,
        platform: defaultTargetPlatform == TargetPlatform.iOS
            ? 'ios'
            : 'android',
      );
    } catch (e) {
      // Not being reachable for reminders is not a reason to interrupt
      // anyone. Log and carry on.
      debugPrint('Push token registration failed: $e');
    }
  }

  unawaited(
    PushService.requestToken().then((token) {
      if (token != null) return register(token);
    }),
  );

  final subscription = PushService.tokenRefreshes.listen(register);
  ref.onDispose(subscription.cancel);
});
