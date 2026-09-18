import 'package:supabase_flutter/supabase_flutter.dart'
    show User, AuthState, AuthChangeEvent;

import '../../../../core/errors/auth_failure.dart';
import '../../domain/entities/app_user.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_remote_datasource.dart';

class AuthRepositoryImpl implements AuthRepository {
  final AuthRemoteDataSource _remote;

  AuthRepositoryImpl(this._remote);

  @override
  Future<AppUser> login({
    required String email,
    required String password,
  }) async {
    try {
      final user = await _remote.signInAndRegisterDevice(
        email: email,
        password: password,
      );
      return _toAppUser(user);
    } on AuthFailure {
      rethrow;
    } catch (e) {
      throw AuthFailure.unknown(e.toString());
    }
  }

  @override
  Future<AppUser?> signUp({
    required String email,
    required String password,
    String? displayName,
  }) async {
    try {
      final user = await _remote.signUp(
        email: email,
        password: password,
        displayName: displayName,
      );
      return user == null ? null : _toAppUser(user);
    } on AuthFailure {
      rethrow;
    } catch (e) {
      throw AuthFailure.unknown(e.toString());
    }
  }

  @override
  Future<AppUser> signInWithGoogle() async {
    try {
      final user = await _remote.signInWithGoogleAndRegisterDevice();
      return _toAppUser(user);
    } on AuthFailure {
      rethrow;
    } catch (e) {
      throw AuthFailure.unknown(e.toString());
    }
  }

  @override
  Future<AppUser> signInWithApple() async {
    try {
      final user = await _remote.signInWithAppleAndRegisterDevice();
      return _toAppUser(user);
    } on AuthFailure {
      rethrow;
    } catch (e) {
      throw AuthFailure.unknown(e.toString());
    }
  }

  @override
  Future<void> logout() => _remote.signOut();

  @override
  Future<void> deleteAccount() async {
    try {
      await _remote.deleteAccount();
    } on AuthFailure {
      rethrow;
    } catch (e) {
      throw AuthFailure.unknown(e.toString());
    }
  }

  @override
  Future<void> sendPasswordResetEmail({required String email}) async {
    try {
      await _remote.sendPasswordResetEmail(email);
    } on AuthFailure {
      rethrow;
    } catch (e) {
      throw AuthFailure.unknown(e.toString());
    }
  }

  @override
  AppUser? get currentUser {
    final user = _remote.currentUser;
    return user == null ? null : _toAppUser(user);
  }

  @override
  Stream<AppUser?> authStateChanges() {
    return _remote.onAuthStateChange.map((AuthState state) {
      // Only an EXPLICIT sign-out means "logged out". Supabase's periodic
      // token refresh fails while offline and emits an event whose session
      // is null — but the session is still valid locally and the person may
      // be mid-playback on a downloaded track with no network. Treating that
      // transient null as a sign-out is what bounced the router to /login and
      // then, once the session re-emitted, on to /home — the "offline
      // playback jumps back to Home after a few seconds" bug. So for every
      // event other than a real signedOut, fall back to the persisted session
      // (which Supabase keeps locally offline) rather than reading null.
      if (state.event == AuthChangeEvent.signedOut) return null;
      final user = state.session?.user ?? _remote.currentUser;
      return user == null ? null : _toAppUser(user);
    });
  }

  AppUser _toAppUser(User user) => AppUser(
        id: user.id,
        email: user.email ?? '',
        // Email/password sign up stores 'display_name'; Google sign-in
        // populates 'full_name'/'name' from the ID token claims instead.
        displayName: user.userMetadata?['display_name'] as String? ??
            user.userMetadata?['full_name'] as String? ??
            user.userMetadata?['name'] as String?,
      );
}
