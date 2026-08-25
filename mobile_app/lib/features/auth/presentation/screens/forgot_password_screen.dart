import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_theme.dart';
import '../../../../app/widgets/soft_halo.dart';
import '../../application/auth_providers.dart';
import '../../application/auth_state.dart';
import '../widgets/auth_scaffold.dart';
import '../widgets/auth_text_field.dart';
import '../widgets/auth_validators.dart';

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  bool _emailSent = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    ref.read(authControllerProvider.notifier).sendPasswordResetEmail(
          email: _emailController.text.trim(),
        );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);
    final isLoading = authState is AuthLoading;

    ref.listen<AuthState>(authControllerProvider, (previous, next) {
      if (next is AuthUnauthenticated && previous is AuthLoading) {
        setState(() => _emailSent = true);
      } else if (next is AuthFailureState) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(next.failure.message)),
        );
      }
    });

    return AuthScaffold(
      title: 'Reset password',
      child: _emailSent
          ? Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 40),
                SizedBox(
                  width: 140,
                  height: 140,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      const SoftHalo(size: 140),
                      Container(
                        width: 90,
                        height: 90,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: AppTheme.clayFill(),
                          boxShadow: AppTheme.cardShadow,
                        ),
                        child: const Icon(
                          Icons.outgoing_mail,
                          size: 40,
                          color: AppTheme.sageDark,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Check your inbox',
                  style: TextStyle(
                    fontFamily: AppTheme.display,
                    fontSize: 26,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'If an account exists for that email, '
                  'a password reset link has been sent.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: AppTheme.text,
                    fontSize: 15,
                    height: 1.5,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            )
          : Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 20),
                  const Text(
                    'Enter your account email and we\'ll send you a '
                    'link to reset your password.',
                    style: TextStyle(
                      fontFamily: AppTheme.text,
                      fontSize: 15,
                      height: 1.5,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 20),
                  AuthTextField(
                    controller: _emailController,
                    label: 'Email',
                    keyboardType: TextInputType.emailAddress,
                    validator: validateEmail,
                  ),
                  const SizedBox(height: 22),
                  PrimaryGradientButton(
                    label: 'Send reset link',
                    loading: isLoading,
                    onPressed: isLoading ? null : _submit,
                  ),
                ],
              ),
            ),
    );
  }
}
