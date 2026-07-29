import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/auth_providers.dart';
import '../../application/auth_state.dart';
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

    return Scaffold(
      appBar: AppBar(title: const Text('Reset password')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: _emailSent
              ? const Center(
                  child: Text(
                    'If an account exists for that email, '
                    'a password reset link has been sent.',
                    textAlign: TextAlign.center,
                  ),
                )
              : Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(height: 24),
                      const Text(
                        'Enter your account email and we\'ll send you a '
                        'link to reset your password.',
                      ),
                      const SizedBox(height: 16),
                      AuthTextField(
                        controller: _emailController,
                        label: 'Email',
                        keyboardType: TextInputType.emailAddress,
                        validator: validateEmail,
                      ),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: isLoading ? null : _submit,
                        child: isLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Text('Send reset link'),
                      ),
                    ],
                  ),
                ),
        ),
      ),
    );
  }
}
