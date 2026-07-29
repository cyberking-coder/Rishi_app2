import '../entities/app_user.dart';
import '../repositories/auth_repository.dart';

class GoogleSignInUseCase {
  final AuthRepository _repository;

  const GoogleSignInUseCase(this._repository);

  Future<AppUser> call() => _repository.signInWithGoogle();
}
