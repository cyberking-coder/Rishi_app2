import '../entities/app_user.dart';

/// Domain-facing contract. The data layer implements this and is the only
/// place that knows about Supabase or device registration.
abstract class AuthRepository {
  /// Signs in, then registers/validates this device against the
  /// account's single active device. Throws [AuthFailure] on any failure,
  /// including device-lock rejection (in which case the session is
  /// signed out again before the error is thrown).
  Future<AppUser> login({required String email, required String password});

  /// Signs in (or creates an account, on first use) via Google OAuth.
  /// Registers/validates this device the same way [login] does — throws
  /// [AuthFailure] on any failure, including device-lock rejection.
  Future<AppUser> signInWithGoogle();

  /// Creates a new account. Returns the signed-in [AppUser] if the project
  /// auto-confirms new accounts (session issued immediately, device also
  /// registered in that case) — otherwise returns null, meaning the
  /// account was created and the caller must confirm their email before
  /// logging in.
  Future<AppUser?> signUp({
    required String email,
    required String password,
    String? displayName,
  });

  Future<void> logout();

  Future<void> sendPasswordResetEmail({required String email});

  AppUser? get currentUser;

  Stream<AppUser?> authStateChanges();
}
