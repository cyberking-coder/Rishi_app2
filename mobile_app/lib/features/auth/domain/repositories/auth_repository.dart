import '../entities/app_user.dart';

/// Domain-facing contract. The data layer implements this and is the only
/// place that knows about Supabase or device registration.
abstract class AuthRepository {
  /// Signs in, then registers/validates this device against the
  /// account's single active device. Throws [AuthFailure] on any failure,
  /// including device-lock rejection (in which case the session is
  /// signed out again before the error is thrown).
  Future<AppUser> login({required String email, required String password});

  /// Creates a new account, then registers this device. Returns `null` when
  /// the project requires email confirmation (no session yet — the caller
  /// must confirm via the emailed link before logging in); returns the new
  /// [AppUser] when the session is created immediately.
  Future<AppUser?> signUp({
    required String email,
    required String password,
    String? displayName,
  });

  /// Signs in (or, for a first-time caller, silently creates the account)
  /// via native Google Sign-In, then registers this device.
  Future<AppUser> signInWithGoogle();

  /// The same, via Sign in with Apple. iOS only in practice — the button
  /// that calls this is not shown elsewhere.
  Future<AppUser> signInWithApple();

  Future<void> logout();

  /// Permanently deletes the caller's own account.
  ///
  /// Identity and personal history go; purchase records survive with no
  /// user attached, because they are financial records the business is
  /// required to keep. Signs out on success.
  Future<void> deleteAccount();

  Future<void> sendPasswordResetEmail({required String email});

  AppUser? get currentUser;

  Stream<AppUser?> authStateChanges();
}
