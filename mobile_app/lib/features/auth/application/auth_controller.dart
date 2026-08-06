import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/auth_failure.dart';
import '../../../core/push/push_service.dart';
import '../../audio/application/audio_providers.dart';
import '../../live/application/live_providers.dart';
import 'auth_providers.dart';
import 'auth_state.dart';

class AuthController extends Notifier<AuthState> {
  @override
  AuthState build() => const AuthInitial();

  Future<void> login({required String email, required String password}) async {
    state = const AuthLoading();
    try {
      final user = await ref
          .read(loginUseCaseProvider)
          .call(email: email, password: password);
      state = AuthAuthenticated(user);
    } on AuthFailure catch (failure) {
      state = AuthFailureState(failure);
    } catch (e) {
      state = AuthFailureState(AuthFailure.unknown(e.toString()));
    }
  }

  Future<void> signUp({
    required String email,
    required String password,
    String? displayName,
  }) async {
    state = const AuthLoading();
    try {
      final user = await ref.read(signUpUseCaseProvider).call(
            email: email,
            password: password,
            displayName: displayName,
          );
      // A null user means the project requires email confirmation — no
      // session yet. Reuse AuthUnauthenticated as the "succeeded, nothing
      // more to do here" signal, same convention as sendPasswordResetEmail.
      state = user != null ? AuthAuthenticated(user) : const AuthUnauthenticated();
    } on AuthFailure catch (failure) {
      state = AuthFailureState(failure);
    } catch (e) {
      state = AuthFailureState(AuthFailure.unknown(e.toString()));
    }
  }

  Future<void> signInWithApple() async {
    state = const AuthLoading();
    try {
      final user = await ref.read(appleSignInUseCaseProvider).call();
      state = AuthAuthenticated(user);
    } on AuthFailure catch (failure) {
      state = AuthFailureState(failure);
    } catch (e) {
      state = AuthFailureState(AuthFailure.unknown(e.toString()));
    }
  }

  Future<void> signInWithGoogle() async {
    state = const AuthLoading();
    try {
      final user = await ref.read(googleSignInUseCaseProvider).call();
      state = AuthAuthenticated(user);
    } on AuthFailure catch (failure) {
      state = AuthFailureState(failure);
    } catch (e) {
      state = AuthFailureState(AuthFailure.unknown(e.toString()));
    }
  }

  Future<void> logout() async {
    state = const AuthLoading();
    try {
      // Stop + clear any audio so the next user never inherits the previous
      // user's mini-player / now-playing track.
      await ref.read(audioHandlerProvider).reset();

      // Same reasoning for push: a token left behind would keep sending
      // this user's session reminders to a handset somebody else may now
      // be signed in on. Done before the sign-out, while the RLS policy
      // on push_tokens still recognises the row as theirs. Best-effort —
      // failing to unregister must never block signing out.
      try {
        final token = await PushService.currentToken();
        if (token != null) {
          await ref.read(liveSessionsDataSourceProvider)
              .unregisterPushToken(token);
        }
      } catch (e) {
        debugPrint('Could not unregister push token: $e');
      }

      await ref.read(logoutUseCaseProvider).call();
      state = const AuthUnauthenticated();
    } catch (e) {
      state = AuthFailureState(AuthFailure.unknown(e.toString()));
    }
  }

  Future<void> sendPasswordResetEmail({required String email}) async {
    state = const AuthLoading();
    try {
      await ref.read(forgotPasswordUseCaseProvider).call(email: email);
      state = const AuthUnauthenticated();
    } on AuthFailure catch (failure) {
      state = AuthFailureState(failure);
    } catch (e) {
      state = AuthFailureState(AuthFailure.unknown(e.toString()));
    }
  }
}
