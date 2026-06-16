import '../repositories/auth_repository.dart';

class ForgotPasswordUseCase {
  final AuthRepository _repository;

  const ForgotPasswordUseCase(this._repository);

  Future<void> call({required String email}) {
    return _repository.sendPasswordResetEmail(email: email);
  }
}
