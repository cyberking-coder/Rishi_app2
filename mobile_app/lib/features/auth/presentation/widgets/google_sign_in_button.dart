import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/auth_providers.dart';

/// "Continue with Google" — used on both the login and signup screens; the
/// underlying action is identical (native Google Sign-In, then Supabase
/// signInWithIdToken), since a first-time Google user is auto-provisioned
/// by the same `handle_new_user` trigger as an email/password sign up.
class GoogleSignInButton extends ConsumerWidget {
  final bool enabled;

  const GoogleSignInButton({super.key, this.enabled = true});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return OutlinedButton.icon(
      onPressed: enabled
          ? () => ref.read(authControllerProvider.notifier).signInWithGoogle()
          : null,
      icon: const Icon(Icons.g_mobiledata, size: 28),
      label: const Text('Continue with Google'),
    );
  }
}
