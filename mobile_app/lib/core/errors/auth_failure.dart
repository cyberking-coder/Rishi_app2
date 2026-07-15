/// Categorized failures surfaced by the auth feature. Kept as a sealed
/// class (not exceptions) so the UI layer can switch on [type] instead of
/// parsing message strings.
enum AuthFailureType {
  invalidCredentials,
  deviceLocked,
  accessExpired,
  emailNotConfirmed,
  network,
  weakPassword,
  userNotFound,
  unknown,
}

class AuthFailure implements Exception {
  final AuthFailureType type;
  final String message;

  const AuthFailure(this.type, this.message);

  factory AuthFailure.invalidCredentials() => const AuthFailure(
        AuthFailureType.invalidCredentials,
        'Incorrect email or password.',
      );

  factory AuthFailure.deviceLocked() => const AuthFailure(
        AuthFailureType.deviceLocked,
        'This account is already active on another device.',
      );

  factory AuthFailure.accessExpired() => const AuthFailure(
        AuthFailureType.accessExpired,
        'Your access period has ended. Please contact support to renew.',
      );

  factory AuthFailure.network() => const AuthFailure(
        AuthFailureType.network,
        'No internet connection. Please try again.',
      );

  factory AuthFailure.unknown([String? detail]) => AuthFailure(
        AuthFailureType.unknown,
        detail ?? 'Something went wrong. Please try again.',
      );

  @override
  String toString() => message;
}
