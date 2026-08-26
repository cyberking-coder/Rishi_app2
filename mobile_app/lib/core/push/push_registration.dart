import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../network/supabase_client_provider.dart';
import 'push_service.dart';

/// Reads and writes `push_tokens`.
///
/// This used to live in `features/live/` — the module built for live
/// sessions, which were removed entirely for the iOS reader-app build.
/// Nothing about registering a device for notifications was ever specific
/// to live sessions; it was filed there because that was the feature
/// being built at the time. The effect was that a folder named `live`
/// stayed alive, and stayed imported by `app_shell.dart`, purely to hold
/// push registration — keeping a compliance-sensitive module in the tree
/// for an unrelated reason. It now lives beside the service it talks to.
class PushTokenDataSource {
  final SupabaseClient _client;

  PushTokenDataSource(this._client);

  /// Records this device's FCM token so notifications can reach it.
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
  /// user's notifications to a handset somebody else may now be holding.
  Future<void> unregisterPushToken(String token) async {
    await _client.from('push_tokens').delete().eq('token', token);
  }
}

final pushTokenDataSourceProvider = Provider<PushTokenDataSource>((ref) {
  return PushTokenDataSource(ref.watch(supabaseClientProvider));
});

/// Registers this device for notifications, once, after sign-in.
///
/// A provider rather than a call site so it can't be run twice from two
/// screens, and so the token-refresh subscription is torn down with the
/// scope rather than leaking. Kept alive deliberately — autoDispose would
/// cancel the refresh listener the moment no screen was watching, which
/// is most of the time.
final pushRegistrationProvider = Provider<void>((ref) {
  final dataSource = ref.watch(pushTokenDataSourceProvider);

  Future<void> register(String token) async {
    try {
      await dataSource.registerPushToken(
        token: token,
        platform:
            defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android',
      );
    } catch (e) {
      // Not being reachable for notifications is not a reason to
      // interrupt anyone. Log and carry on.
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
