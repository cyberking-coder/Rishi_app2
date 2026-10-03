import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/network/supabase_client_provider.dart';
import '../../downloads/application/download_providers.dart';
import '../data/offline_session_store.dart';
import '../domain/entities/app_access_mode.dart';

/// The ONE place that decides the app's access state. Splash, router and
/// every screen read [appAccessModeProvider] instead of each re-deriving
/// "am I logged in?" — the divergence that produced the reinstall bug.
///
/// Identity is the Supabase session. The offline token ([OfflineSessionStore])
/// is only a time-boxed local permission to play already-verified downloads.
class AppAccessController extends Notifier<AppAccessMode> {
  late final SupabaseClient _client;
  late final OfflineSessionStore _store;
  StreamSubscription<AuthState>? _authSub;
  StreamSubscription<List<ConnectivityResult>>? _connSub;
  bool _resolving = false;

  @override
  AppAccessMode build() {
    _client = ref.watch(supabaseClientProvider);
    _store = OfflineSessionStore();

    // React to real auth transitions for the life of the app.
    _authSub = _client.auth.onAuthStateChange.listen(_onAuthEvent);

    // When connectivity returns, reconcile: re-verify the session (which
    // slides the offline grace window forward) and purge anything the server
    // revoked while we were offline. Only act on a transition to having a
    // network, and never while a resolve is already in flight.
    _connSub = Connectivity().onConnectivityChanged.listen((results) {
      final hasNetwork = results.any((r) => r != ConnectivityResult.none);
      if (hasNetwork && !_resolving) unawaited(resolve());
    });

    ref.onDispose(() {
      _authSub?.cancel();
      _connSub?.cancel();
    });

    // Kick off resolution; stay in `resolving` until it lands.
    unawaited(resolve());
    return AppAccessMode.resolving;
  }

  Future<void> _onAuthEvent(AuthState data) async {
    final event = data.event;
    if (event == AuthChangeEvent.signedOut ||
        event == AuthChangeEvent.userDeleted) {
      // Definitive sign-out (incl. a stale restored session gotrue rejected).
      await _store.clear();
      state = AppAccessMode.signedOut;
      return;
    }
    final session = data.session ?? _client.auth.currentSession;
    if (session != null) {
      await _store.markVerified(userId: session.user.id);
      state = AppAccessMode.authenticatedOnline;
    }
  }

  /// Resolves the mode at startup (and can be re-run on connectivity return).
  Future<void> resolve() async {
    if (_resolving) return;
    _resolving = true;
    try {
      final session = _client.auth.currentSession;
      final offline = await _store.read();
      final hasNetwork = await _hasNetwork();

      if (session != null) {
        await _store.markVerified(userId: session.user.id);
        state = AppAccessMode.authenticatedOnline;
        unawaited(_reconcileDownloads());
        return;
      }

      var decision = decideAccessMode(
        hasSession: false,
        hasOfflineIdentity: offline != null,
        offlineStillValid: offline?.isStillValid() ?? false,
        hasNetwork: hasNetwork,
      );

      // The online-with-offline-identity branch needs a refresh to decide.
      if (decision == AppAccessMode.resolving) {
        final outcome = await _attemptRefresh();
        decision = decideAccessMode(
          hasSession: false,
          hasOfflineIdentity: offline != null,
          offlineStillValid: offline?.isStillValid() ?? false,
          hasNetwork: hasNetwork,
          refreshOutcome: outcome,
        );
        if (outcome == RefreshOutcome.success) {
          final uid = _client.auth.currentSession?.user.id;
          if (uid != null) await _store.markVerified(userId: uid);
        } else if (outcome == RefreshOutcome.invalid) {
          await _store.clear();
        }
      }

      state = decision;
      if (decision == AppAccessMode.authenticatedOnline) {
        unawaited(_reconcileDownloads());
      }
    } finally {
      _resolving = false;
    }
  }

  /// Best-effort server reconciliation once online: drop downloads whose
  /// license expired or was revoked server-side. Never throws into the UI.
  Future<void> _reconcileDownloads() async {
    try {
      await ref.read(downloadRepositoryProvider).purgeRevokedAndExpired();
    } catch (_) {
      // Transient / offline again — the next online resolve retries.
    }
  }

  Future<RefreshOutcome> _attemptRefresh() async {
    try {
      final res =
          await _client.auth.refreshSession().timeout(const Duration(seconds: 10));
      return res.session != null
          ? RefreshOutcome.success
          : RefreshOutcome.invalid;
    } on AuthException {
      // Server reachable, refresh token missing/rejected → definitive.
      return RefreshOutcome.invalid;
    } catch (_) {
      // Network/timeout → not a credential problem.
      return RefreshOutcome.networkError;
    }
  }

  Future<bool> _hasNetwork() async {
    try {
      final results = await Connectivity().checkConnectivity();
      return results.any((r) => r != ConnectivityResult.none);
    } catch (_) {
      // Unknown → assume online; the refresh attempt will correct it.
      return true;
    }
  }

  /// Called right after a successful interactive login/signup/social sign-in:
  /// write the verified offline token and flip to online immediately.
  Future<void> onVerifiedOnline(String userId) async {
    await _store.markVerified(userId: userId);
    state = AppAccessMode.authenticatedOnline;
  }

  /// Called on explicit logout or account deletion.
  Future<void> onSignedOut() async {
    await _store.clear();
    state = AppAccessMode.signedOut;
  }
}

final appAccessModeProvider =
    NotifierProvider<AppAccessController, AppAccessMode>(
        AppAccessController.new);
