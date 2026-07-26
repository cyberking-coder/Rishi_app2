import '../../../core/errors/auth_failure.dart';
import '../domain/entities/app_user.dart';

sealed class AuthState {
  const AuthState();
}

class AuthInitial extends AuthState {
  const AuthInitial();
}

class AuthLoading extends AuthState {
  const AuthLoading();
}

class AuthAuthenticated extends AuthState {
  final AppUser user;
  const AuthAuthenticated(this.user);
}

class AuthUnauthenticated extends AuthState {
  const AuthUnauthenticated();
}

/// Sign-up succeeded but the project requires email confirmation before a
/// session is issued — distinct from [AuthUnauthenticated] so the sign-up
/// screen can show a "check your email" message instead of a plain form.
class AuthSignUpPending extends AuthState {
  const AuthSignUpPending();
}

class AuthFailureState extends AuthState {
  final AuthFailure failure;
  const AuthFailureState(this.failure);
}
