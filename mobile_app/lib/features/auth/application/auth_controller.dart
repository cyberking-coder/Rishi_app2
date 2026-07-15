import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/auth_failure.dart';
import '../../audio/application/audio_providers.dart';
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

  Future<void> logout() async {
    state = const AuthLoading();
    try {
      // Stop + clear any audio so the next user never inherits the previous
      // user's mini-player / now-playing track.
      await ref.read(audioHandlerProvider).reset();
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
