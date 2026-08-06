import '../entities/app_user.dart';
import '../repositories/auth_repository.dart';

class AppleSignInUseCase {
  final AuthRepository _repository;

  const AppleSignInUseCase(this._repository);

  Future<AppUser> call() => _repository.signInWithApple();
}
