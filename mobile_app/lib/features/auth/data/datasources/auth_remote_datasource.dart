import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
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

  /// Signs in with Apple, then registers this device.
  ///
  /// Required by App Store Guideline 4.8, which asks any app offering a
  /// third-party login to offer this one beside it.
  ///
  /// The nonce is the fiddly part and it is not optional. Apple signs a
  /// SHA-256 hash of it into the identity token; Supabase re-hashes the
  /// raw value we pass and compares. Send the hash to Supabase, or the
  /// raw value to Apple, and it fails with a message about the nonce
  /// that does not say which way round is wrong.
  Future<User> signInWithAppleAndRegisterDevice() async {
    final rawNonce = _client.auth.generateRawNonce();
    final hashedNonce = sha256.convert(utf8.encode(rawNonce)).toString();

    final AuthorizationCredentialAppleID credential;
    try {
      credential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        nonce: hashedNonce,
      );
    } on SignInWithAppleAuthorizationException catch (e) {
      if (e.code == AuthorizationErrorCode.canceled) {
        throw AuthFailure.googleSignInCancelled();
      }
      throw AuthFailure.unknown('Apple sign-in failed: ${e.message}');
    } catch (e) {
      throw AuthFailure.unknown('Apple sign-in failed: $e');
    }

    final idToken = credential.identityToken;
    if (idToken == null) {
      throw AuthFailure.unknown('Apple sign-in failed: missing ID token.');
    }

    final AuthResponse response;
    try {
      response = await _client.auth.signInWithIdToken(
        provider: OAuthProvider.apple,
        idToken: idToken,
        nonce: rawNonce,
      );
    } on AuthException catch (e) {
      throw _mapAuthException(e);
    }

    final user = response.user;
    if (user == null) {
      throw AuthFailure.unknown('Apple sign-in failed. Please try again.');
    }

    // Apple sends the name ONCE, on the very first authorisation, and
    // never again — not on any later sign-in, and not if the account is
    // deleted and recreated. If it is not captured here it is gone, and
    // the app greets the person by email address forever.
    final given = credential.givenName?.trim() ?? '';
    final family = credential.familyName?.trim() ?? '';
    final fullName = [given, family].where((p) => p.isNotEmpty).join(' ');

    if (fullName.isNotEmpty) {
      try {
        // Only ever fills a blank. A returning user who set their own
        // name keeps it.
        await _client
            .from('profiles')
            .update({'display_name': fullName})
            .eq('id', user.id)
            .isFilter('display_name', null);
      } catch (_) {
        // A missing name is not a reason to fail a sign-in.
      }
    }

    try {
      await _registerDevice();
    } on DeviceLockedException {
      await signOut();
      throw AuthFailure.deviceLocked();
    }

    return user;
  }

  /// Deletes the caller's own account, then signs out.
  ///
  /// The work happens in the delete-account edge function — removing an
  /// auth user needs the service role, which the app must never hold.
  Future<void> deleteAccount() async {
    final response = await _client.functions.invoke('delete-account');

    if (response.status != 200) {
      final detail = response.data is Map
          ? (response.data as Map)['error'] as String?
          : null;
      throw AuthFailure.unknown(
        detail ?? 'Could not delete your account. Please try again.',
      );
    }

    // The account is already gone server-side; this just clears the
    // local session and the cached Google account so the next launch
    // starts clean rather than holding a token for a user who no longer
    // exists.
    await signOut();
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
