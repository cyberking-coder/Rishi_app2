import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/device/device_info_service.dart';
import '../../../../core/errors/auth_failure.dart';

/// Raised internally when the `register_device` RPC rejects the login
/// because another device already holds the active session.
class DeviceLockedException implements Exception {}

class AuthRemoteDataSource {
  final SupabaseClient _client;
  final DeviceInfoService _deviceInfoService;

  AuthRemoteDataSource(this._client, this._deviceInfoService);

  User? get currentUser => _client.auth.currentUser;

  Stream<AuthState> get onAuthStateChange => _client.auth.onAuthStateChange;

  /// Signs in with email/password, then registers this device. If the
  /// account is already active on a different device, the RPC throws and
  /// we immediately sign the session back out so no partially-authed
  /// state leaks into the app.
  Future<User> signInAndRegisterDevice({
    required String email,
    required String password,
  }) async {
    final AuthResponse response;
    try {
      response = await _client.auth.signInWithPassword(
        email: email,
        password: password,
      );
    } on AuthException catch (e) {
      throw _mapAuthException(e);
    }

    final user = response.user;
    if (user == null) {
      throw AuthFailure.unknown('Login failed. Please try again.');
    }

    try {
      await _registerDevice();
    } on DeviceLockedException {
      await _client.auth.signOut();
      throw AuthFailure.deviceLocked();
    }

    return user;
  }

  /// Creates a new account. If the Supabase project auto-confirms new
  /// users (a session comes back immediately), this also registers the
  /// device — the same device-lock enforcement applies to a self-signup as
  /// to any login. Returns null when email confirmation is required
  /// instead (no session yet); the caller shows a "check your email"
  /// message in that case.
  Future<User?> signUp({
    required String email,
    required String password,
    String? displayName,
  }) async {
    final AuthResponse response;
    try {
      response = await _client.auth.signUp(
        email: email,
        password: password,
        data: displayName == null || displayName.isEmpty
            ? null
            : {'display_name': displayName},
        emailRedirectTo: AppConfig.authRedirectUrl,
      );
    } on AuthException catch (e) {
      throw _mapAuthException(e);
    }

    final user = response.user;
    if (user == null) {
      throw AuthFailure.unknown('Sign up failed. Please try again.');
    }

    if (response.session == null) {
      // Email confirmation required — no active session yet.
      return null;
    }

    try {
      await _registerDevice();
    } on DeviceLockedException {
      await _client.auth.signOut();
      throw AuthFailure.deviceLocked();
    }

    return user;
  }

  /// Launches Google sign-in via a browser-based OAuth redirect. Unlike
  /// [signInAndRegisterDevice]/[signUp], the resulting session doesn't come
  /// back as a direct return value — the browser redirect completes
  /// asynchronously via the `meditationapp://login-callback` deep link, so
  /// this waits for the auth stream to report a signed-in session before
  /// registering the device, mirroring the same device-lock enforcement as
  /// any other sign-in method.
  Future<User> signInWithGoogle() async {
    try {
      await _client.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: AppConfig.authRedirectUrl,
      );
    } on AuthException catch (e) {
      throw _mapAuthException(e);
    }

    final authState = await _client.auth.onAuthStateChange
        .firstWhere((s) => s.event == AuthChangeEvent.signedIn)
        .timeout(
          const Duration(minutes: 2),
          onTimeout: () =>
              throw AuthFailure.unknown('Google sign-in was not completed.'),
        );

    final user = authState.session?.user;
    if (user == null) {
      throw AuthFailure.unknown('Google sign-in failed. Please try again.');
    }

    try {
      await _registerDevice();
    } on DeviceLockedException {
      await _client.auth.signOut();
      throw AuthFailure.deviceLocked();
    }

    return user;
  }

  Future<void> _registerDevice() async {
    final profile = await _deviceInfoService.getDeviceProfile();
    try {
      await _client.rpc('register_device', params: {
        'p_device_fingerprint': profile.fingerprint,
        'p_device_name': profile.name,
        'p_platform': profile.platform,
      });
    } on PostgrestException catch (e) {
      if (e.hint == 'DEVICE_LOCKED' ||
          e.message.contains('already active on another device')) {
        throw DeviceLockedException();
      }
      rethrow;
    }
  }

  Future<void> signOut() => _client.auth.signOut();

  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _client.auth.resetPasswordForEmail(
        email,
        redirectTo: AppConfig.passwordResetRedirectUrl,
      );
    } on AuthException catch (e) {
      throw _mapAuthException(e);
    }
  }

  AuthFailure _mapAuthException(AuthException e) {
    final message = e.message.toLowerCase();
    if (message.contains('invalid login credentials')) {
      return AuthFailure.invalidCredentials();
    }
    if (message.contains('email not confirmed')) {
      return const AuthFailure(
        AuthFailureType.emailNotConfirmed,
        'Please verify your email before logging in.',
      );
    }
    if (message.contains('already registered') ||
        message.contains('already exists')) {
      return AuthFailure.emailAlreadyRegistered();
    }
    if (message.contains('password') &&
        (message.contains('weak') || message.contains('at least'))) {
      return AuthFailure.weakPassword(e.message);
    }
    return AuthFailure.unknown(e.message);
  }
}
