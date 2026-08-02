import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_theme.dart';
import '../../../../core/network/supabase_client_provider.dart';
import '../../application/lms_providers.dart';

/// Landing point for `meditationapp://app/payment-success?course_id=…`,
/// opened by the web checkout page once Razorpay confirms payment.
///
/// Waits for access before forwarding, rather than assuming it. Access is
/// granted by razorpay-webhook, which Razorpay calls server-to-server —
/// that call and this deep link are two independent races started at the
/// same moment, and the deep link usually wins. Dropping the cached
/// answer and navigating immediately therefore re-read the database a
/// beat too early and landed the buyer on the course still locked,
/// seconds after paying for it.
///
/// So it polls has_course_access — the same function the app's lock UI
/// and the license functions read — until it says yes.
class PaymentSuccessScreen extends ConsumerStatefulWidget {
  final String? courseId;

  const PaymentSuccessScreen({super.key, this.courseId});

  @override
  ConsumerState<PaymentSuccessScreen> createState() =>
      _PaymentSuccessScreenState();
}

class _PaymentSuccessScreenState extends ConsumerState<PaymentSuccessScreen> {
  /// Long enough for a webhook that is merely slow, short enough that
  /// nobody is left staring at a spinner wondering if it worked.
  static const _timeout = Duration(seconds: 20);
  static const _interval = Duration(seconds: 2);

  bool _slow = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _waitForAccess());
  }

  Future<void> _waitForAccess() async {
    final courseId = widget.courseId;
    if (courseId == null || courseId.isEmpty) {
      if (mounted) context.go('/courses');
      return;
    }

    final client = ref.read(supabaseClientProvider);
    final deadline = DateTime.now().add(_timeout);

    while (mounted) {
      bool granted = false;
      try {
        final result = await client.rpc(
          'has_course_access',
          params: {
            'p_user_id': client.auth.currentUser?.id,
            'p_course_id': courseId,
          },
        );
        granted = result == true;
      } catch (_) {
        // A failed check is not a failed payment — keep waiting and let
        // the deadline decide.
      }

      if (granted || DateTime.now().isAfter(deadline)) break;

      // Tell the buyer something is still happening before they start
      // wondering whether their money vanished.
      if (mounted && !_slow) setState(() => _slow = true);
      await Future<void>.delayed(_interval);
    }

    if (!mounted) return;

    // Invalidate AFTER the wait, not before: doing it first would only
    // have refreshed the stale "locked" answer.
    ref.invalidate(coursesProvider);
    ref.invalidate(courseDetailProvider(courseId));

    // go(), not push(): this screen is a waypoint and must not sit in the
    // back stack for the user to land on again.
    context.go('/course/$courseId');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(
                  color: AppTheme.sage, strokeWidth: 2),
              const SizedBox(height: 16),
              const Text(
                'Unlocking your course…',
                style: TextStyle(fontSize: 14, color: AppTheme.textSecondary),
              ),
              if (_slow) ...[
                const SizedBox(height: 8),
                const Text(
                  'Confirming your payment — this can take a few seconds.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
