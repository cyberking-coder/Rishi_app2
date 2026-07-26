import 'package:supabase_flutter/supabase_flutter.dart' show User, AuthState;

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
  Future<void> logout() => _remote.signOut();

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
      final user = state.session?.user;
      return user == null ? null : _toAppUser(user);
    });
  }

  AppUser _toAppUser(User user) => AppUser(
        id: user.id,
        email: user.email ?? '',
        displayName: user.userMetadata?['display_name'] as String?,
      );
}
