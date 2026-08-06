import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/device/device_info_service.dart';
import '../../../core/network/supabase_client_provider.dart';
import '../data/datasources/auth_remote_datasource.dart';
import '../data/repositories/auth_repository_impl.dart';
import '../domain/entities/app_user.dart';
import '../domain/repositories/auth_repository.dart';
import '../domain/usecases/forgot_password_usecase.dart';
import '../domain/usecases/apple_sign_in_usecase.dart';
import '../domain/usecases/delete_account_usecase.dart';
import '../domain/usecases/google_sign_in_usecase.dart';
import '../domain/usecases/login_usecase.dart';
import '../domain/usecases/logout_usecase.dart';
import '../domain/usecases/signup_usecase.dart';
import 'auth_controller.dart';
import 'auth_state.dart';

final authRemoteDataSourceProvider = Provider<AuthRemoteDataSource>((ref) {
  return AuthRemoteDataSource(
    ref.watch(supabaseClientProvider),
    ref.watch(deviceInfoServiceProvider),
  );
});

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepositoryImpl(ref.watch(authRemoteDataSourceProvider));
});

final loginUseCaseProvider = Provider<LoginUseCase>((ref) {
  return LoginUseCase(ref.watch(authRepositoryProvider));
});

final logoutUseCaseProvider = Provider<LogoutUseCase>((ref) {
  return LogoutUseCase(ref.watch(authRepositoryProvider));
});

final forgotPasswordUseCaseProvider = Provider<ForgotPasswordUseCase>((ref) {
  return ForgotPasswordUseCase(ref.watch(authRepositoryProvider));
});

final signUpUseCaseProvider = Provider<SignUpUseCase>((ref) {
  return SignUpUseCase(ref.watch(authRepositoryProvider));
});

final googleSignInUseCaseProvider = Provider<GoogleSignInUseCase>((ref) {
  return GoogleSignInUseCase(ref.watch(authRepositoryProvider));
});

final appleSignInUseCaseProvider = Provider<AppleSignInUseCase>((ref) {
  return AppleSignInUseCase(ref.watch(authRepositoryProvider));
});

final deleteAccountUseCaseProvider = Provider<DeleteAccountUseCase>((ref) {
  return DeleteAccountUseCase(ref.watch(authRepositoryProvider));
});

final authControllerProvider =
    NotifierProvider<AuthController, AuthState>(AuthController.new);

/// Stream of the live Supabase session mapped to [AppUser], used by
/// GoRouter's redirect logic to gate authenticated routes.
final authStateChangesProvider = StreamProvider<AppUser?>((ref) {
  return ref.watch(authRepositoryProvider).authStateChanges();
});
