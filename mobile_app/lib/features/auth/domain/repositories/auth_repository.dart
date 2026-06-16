import '../entities/app_user.dart';

/// Domain-facing contract. The data layer implements this and is the only
/// place that knows about Supabase or device registration.
abstract class AuthRepository {
  /// Signs in, then registers/validates this device against the
  /// account's single active device. Throws [AuthFailure] on any failure,
  /// including device-lock rejection (in which case the session is
  /// signed out again before the error is thrown).
  Future<AppUser> login({required String email, required String password});

  Future<void> logout();

  Future<void> sendPasswordResetEmail({required String email});

  AppUser? get currentUser;

  Stream<AppUser?> authStateChanges();
}
