import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/config/google_auth_config.dart';
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

  /// Creates a new account, then registers this device. Returns `null` if
  /// the project requires email confirmation (no session issued yet).
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
      );
    } on AuthException catch (e) {
      throw _mapSignUpException(e);
    }

    if (response.session == null) {
      // Supabase doesn't error when the email already belongs to an
      // account (avoids leaking which emails are registered) - it silently
      // sends no email and returns a user with an empty `identities` list
      // instead. That's the only way to tell "no email was sent because
      // this account already exists" apart from a real new signup.
      if (response.user?.identities?.isEmpty ?? false) {
        throw AuthFailure.emailAlreadyRegistered();
      }
      // Email confirmation required — no session until the user verifies.
      return null;
    }

    final user = response.user;
    if (user == null) {
      throw AuthFailure.unknown('Sign up failed. Please try again.');
    }

    try {
      await _registerDevice();
    } on DeviceLockedException {
      await _client.auth.signOut();
      throw AuthFailure.deviceLocked();
    }

    return user;
  }

  /// Signs in with Google via the native account picker, then exchanges the
  /// ID token with Supabase and registers this device. Works identically
  /// for a brand-new Google user (the `handle_new_user` trigger provisions
  /// their profile the same way it does for email/password sign up) and a
  /// returning one.
  Future<User> signInWithGoogleAndRegisterDevice() async {
    if (!isGoogleSignInConfigured) {
      throw AuthFailure.googleSignInNotConfigured();
    }

    final googleSignIn = GoogleSignIn(serverClientId: googleWebClientId);
    final GoogleSignInAccount? googleUser;
    try {
      googleUser = await googleSignIn.signIn();
    } catch (e) {
      throw AuthFailure.unknown('Google sign-in failed: $e');
    }
    if (googleUser == null) {
      throw AuthFailure.googleSignInCancelled();
    }

    final googleAuth = await googleUser.authentication;
    final idToken = googleAuth.idToken;
    if (idToken == null) {
      throw AuthFailure.unknown('Google sign-in failed: missing ID token.');
    }

    final AuthResponse response;
    try {
      response = await _client.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
        accessToken: googleAuth.accessToken,
      );
    } on AuthException catch (e) {
      throw _mapAuthException(e);
    }

    final user = response.user;
    if (user == null) {
      throw AuthFailure.unknown('Google sign-in failed. Please try again.');
    }

    try {
      await _registerDevice();
    } on DeviceLockedException {
      // Also clear the cached Google account here (not just Supabase),
      // otherwise a device-locked rejection would leave the next
      // "Continue with Google" attempt silently reusing the same blocked
      // account instead of letting the user pick a different one.
      await signOut();
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

  Future<void> signOut() async {
    await _client.auth.signOut();
    // Also clear the cached Google account, otherwise google_sign_in
    // silently re-signs the user into the same account on the next
    // "Continue with Google" tap instead of showing the account picker.
    if (isGoogleSignInConfigured) {
      await GoogleSignIn(serverClientId: googleWebClientId).signOut();
    }
  }

  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _client.auth.resetPasswordForEmail(email);
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
    return AuthFailure.unknown(e.message);
  }

  AuthFailure _mapSignUpException(AuthException e) {
    final message = e.message.toLowerCase();
    if (message.contains('already registered') ||
        message.contains('already exists') ||
        message.contains('user already')) {
      return AuthFailure.emailAlreadyRegistered();
    }
    if (message.contains('password')) {
      return AuthFailure.weakPassword(e.message);
    }
    return AuthFailure.unknown(e.message);
  }
}
