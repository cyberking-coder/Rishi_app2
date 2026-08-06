import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_theme.dart';
import '../../../../app/widgets/botanical.dart';
import '../../../../app/widgets/lotus_logo.dart';
import '../../application/auth_providers.dart';
import '../../application/auth_state.dart';
import '../widgets/apple_sign_in_button.dart';
import '../widgets/auth_scaffold.dart';
import '../widgets/auth_text_field.dart';
import '../widgets/auth_validators.dart';
import '../widgets/google_sign_in_button.dart';

class SignupScreen extends ConsumerStatefulWidget {
  const SignupScreen({super.key});

  @override
  ConsumerState<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends ConsumerState<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _displayNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _signedUp = false;

  @override
  void dispose() {
    _displayNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    ref.read(authControllerProvider.notifier).signUp(
          email: _emailController.text.trim(),
          password: _passwordController.text,
          displayName: _displayNameController.text.trim(),
        );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);
    final isLoading = authState is AuthLoading;

    ref.listen<AuthState>(authControllerProvider, (previous, next) {
      if (next is AuthAuthenticated) {
        context.go('/home');
      } else if (next is AuthUnauthenticated && previous is AuthLoading) {
        setState(() => _signedUp = true);
      } else if (next is AuthFailureState) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(next.failure.message)),
        );
      }
    });

    return AuthScaffold(
      title: 'Create account',
      child: _signedUp
          ? const _CheckYourEmailView()
          : Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Center(child: _SignupBadge()),
                  const SizedBox(height: 10),
                  const Text(
                    'Join Know Thyself',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: AppTheme.display,
                      fontSize: 32,
                      height: 38 / 32,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Create your account and start your journey',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: AppTheme.text,
                      fontSize: 15,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 22),
                  AuthTextField(
                    controller: _displayNameController,
                    label: 'Name (optional)',
                    hint: 'Enter your name',
                    icon: Icons.person_outline_rounded,
                    validator: (_) => null,
                  ),
                  const SizedBox(height: 14),
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
                    hint: 'Create a strong password',
                    obscureText: true,
                    validator: validateNewPassword,
                  ),
                  const SizedBox(height: 8),
                  // The rule the validator enforces, said once before it
                  // is enforced. A password rejected by a rule nobody was
                  // shown reads as the app being difficult.
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                    decoration: BoxDecoration(
                      color: AppTheme.sageSoft.withValues(alpha: 0.6),
                      borderRadius:
                          BorderRadius.circular(AppTheme.radiusTile),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.verified_user_outlined,
                            size: 16, color: AppTheme.sageDark),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'At least 8 characters, with a letter, a number, '
                            'and a symbol.',
                            style: TextStyle(
                              fontFamily: AppTheme.text,
                              fontSize: 12.5,
                              height: 1.35,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  AuthTextField(
                    controller: _confirmPasswordController,
                    label: 'Confirm password',
                    hint: 'Re-enter your password',
                    obscureText: true,
                    validator: (value) {
                      if (value != _passwordController.text) {
                        return 'Passwords do not match';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 22),
                  PrimaryGradientButton(
                    label: 'Create account',
                    loading: isLoading,
                    showArrow: true,
                    onPressed: isLoading ? null : _submit,
                  ),
                  const SizedBox(height: 20),
                  const AuthDivider(),
                  const SizedBox(height: 20),
                  GoogleSignInButton(enabled: !isLoading, outlined: true),
                  if (AppleSignInButton.isSupported) ...[
                    const SizedBox(height: 12),
                    AppleSignInButton(enabled: !isLoading),
                  ],
                  const SizedBox(height: 14),
                  Center(
                    child: TextButton(
                      onPressed: isLoading ? null : () => context.pop(),
                      child: RichText(
                        text: const TextSpan(
                          style: TextStyle(
                            fontFamily: AppTheme.text,
                            fontSize: 15,
                            color: AppTheme.textSecondary,
                          ),
                          children: [
                            TextSpan(text: 'Already have an account? '),
                            TextSpan(
                              text: 'Log in',
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
                  const SizedBox(height: 8),
                  const AuthInfoCard(
                    icon: Icons.shield_outlined,
                    title: 'Your security matters',
                    body: 'Your password is encrypted and never stored in '
                        'plain text. We will never share your details.',
                  ),
                ],
              ),
            ),
    );
  }
}

/// The lotus badge above the signup heading, flanked by sprigs — the
/// design's way of saying this is the same doorway as the login screen.
class _SignupBadge extends StatelessWidget {
  const _SignupBadge();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 132,
      height: 132,
      child: Stack(
        alignment: Alignment.center,
        children: [
          const SoftHalo(size: 132),
          const Sparkles(size: 110, color: Colors.white),
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: AppTheme.clayFill(),
              boxShadow: AppTheme.rowShadow,
            ),
            child: const Center(
              child: LotusLogo(size: 46, color: AppTheme.sageDark),
            ),
          ),
          const Positioned(
            right: -6,
            bottom: 26,
            child: LeafSprig(size: 66, angle: -0.4, opacity: 0.85),
          ),
        ],
      ),
    );
  }
}

class _CheckYourEmailView extends StatelessWidget {
  const _CheckYourEmailView();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 30),
        SizedBox(
          width: 150,
          height: 150,
          child: Stack(
            alignment: Alignment.center,
            children: [
              const SoftHalo(size: 150),
              Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: AppTheme.clayFill(),
                  boxShadow: AppTheme.cardShadow,
                ),
                child: const Icon(
                  Icons.mark_email_read_outlined,
                  size: 44,
                  color: AppTheme.sageDark,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        const Text(
          'Check your email',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: AppTheme.display,
            fontSize: 28,
            fontWeight: FontWeight.w600,
            color: AppTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 10),
        const Text(
          'We\'ve sent you a confirmation link. Tap it to activate your '
          'account, then come back here and log in.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: AppTheme.text,
            fontSize: 15,
            height: 1.5,
            color: AppTheme.textSecondary,
          ),
        ),
        const SizedBox(height: 26),
        PrimaryGradientButton(
          label: 'Back to log in',
          onPressed: () => context.go('/login'),
        ),
      ],
    );
  }
}
