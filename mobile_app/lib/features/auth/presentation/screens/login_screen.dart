import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_theme.dart';
import '../../../../app/widgets/botanical.dart';
import '../../../../app/widgets/lotus_logo.dart';
import '../../../../core/errors/auth_failure.dart';
import '../../application/auth_providers.dart';
import '../../application/auth_state.dart';
import '../widgets/auth_scaffold.dart';
import '../widgets/auth_text_field.dart';
import '../widgets/auth_validators.dart';
import '../widgets/google_sign_in_button.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    ref.read(authControllerProvider.notifier).login(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);
    final isLoading = authState is AuthLoading;

    ref.listen<AuthState>(authControllerProvider, (previous, next) {
      if (next is AuthAuthenticated) {
        context.go('/home');
      } else if (next is AuthFailureState) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.failure.message),
            backgroundColor: next.failure.type == AuthFailureType.deviceLocked
                ? Colors.redAccent
                : null,
          ),
        );
      }
    });

    return AuthScaffold(
      footer: const AuthFooterNote(
        icon: Icons.shield_outlined,
        title: 'Security first',
        body: 'Your privacy and security are our top priority.',
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            const Center(child: _BrandBadge()),
            const SizedBox(height: 18),
            const Text(
              'Welcome back',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: AppTheme.display,
                fontSize: 34,
                height: 40 / 34,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Log in to continue your journey',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: AppTheme.text,
                fontSize: 15.5,
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 26),
            AuthTextField(
              controller: _emailController,
              label: 'Email',
              keyboardType: TextInputType.emailAddress,
              validator: validateEmail,
            ),
            const SizedBox(height: 14),
            AuthTextField(
              controller: _passwordController,
              label: 'Password',
              obscureText: true,
              validator: validatePasswordRequired,
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed:
                    isLoading ? null : () => context.push('/forgot-password'),
                child: const Text(
                  'Forgot password?',
                  style: TextStyle(
                    fontFamily: AppTheme.text,
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.sageDark,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 6),
            PrimaryGradientButton(
              label: 'Log in',
              loading: isLoading,
              onPressed: isLoading ? null : _submit,
            ),
            const SizedBox(height: 20),
            const AuthDivider(),
            const SizedBox(height: 20),
            GoogleSignInButton(enabled: !isLoading),
            const SizedBox(height: 18),
            Center(
              child: TextButton(
                onPressed: isLoading ? null : () => context.push('/signup'),
                child: RichText(
                  text: const TextSpan(
                    style: TextStyle(
                      fontFamily: AppTheme.text,
                      fontSize: 15,
                      color: AppTheme.textSecondary,
                    ),
                    children: [
                      TextSpan(text: 'New here? '),
                      TextSpan(
                        text: 'Create a free account',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: AppTheme.sageDark,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            // Sets expectations up front for the one-device-per-account
            // lock, so a user hitting it later understands why rather
            // than reading it as a bug.
            const AuthInfoCard(
              icon: Icons.phonelink_lock_outlined,
              title: 'One account. One device.',
              body: 'One account can be used on one device only. Logging in '
                  'on a new device will not work until the previous one is '
                  'released.',
            ),
          ],
        ),
      ),
    );
  }
}

/// The lotus in its halo, above the greeting. Smaller than the splash
/// mark and without the sparkles — this one is identification, not a
/// curtain-raiser.
class _BrandBadge extends StatelessWidget {
  const _BrandBadge();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 150,
      height: 150,
      child: Stack(
        alignment: Alignment.center,
        children: [
          const SoftHalo(size: 150),
          Container(
            width: 104,
            height: 104,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: AppTheme.clayFill(),
              boxShadow: AppTheme.cardShadow,
            ),
            child: const Center(
              child: LotusLogo(size: 54, color: AppTheme.sageDark),
            ),
          ),
          const Positioned(
            right: 2,
            bottom: 24,
            child: LeafSprig(size: 74, angle: -0.35, opacity: 0.85),
          ),
        ],
      ),
    );
  }
}
