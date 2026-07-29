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
  emailAlreadyRegistered,
  googleSignInCancelled,
  googleSignInNotConfigured,
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

  factory AuthFailure.weakPassword([String? detail]) => AuthFailure(
        AuthFailureType.weakPassword,
        detail ?? 'Password should be at least 6 characters.',
      );

  factory AuthFailure.emailAlreadyRegistered() => const AuthFailure(
        AuthFailureType.emailAlreadyRegistered,
        'An account with this email already exists. Try logging in instead.',
      );

  factory AuthFailure.googleSignInCancelled() => const AuthFailure(
        AuthFailureType.googleSignInCancelled,
        'Google sign-in was cancelled.',
      );

  factory AuthFailure.googleSignInNotConfigured() => const AuthFailure(
        AuthFailureType.googleSignInNotConfigured,
        'Google sign-in is not set up yet. Please use email/password.',
      );

  factory AuthFailure.unknown([String? detail]) => AuthFailure(
        AuthFailureType.unknown,
        detail ?? 'Something went wrong. Please try again.',
      );

  @override
  String toString() => message;
}
