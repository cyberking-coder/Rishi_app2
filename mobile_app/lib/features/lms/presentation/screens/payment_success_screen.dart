import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_theme.dart';
import '../../application/lms_providers.dart';

/// Landing point for `meditationapp://app/payment-success?course_id=…`,
/// opened by the web checkout page once Razorpay confirms payment.
///
/// Access is granted server-side by razorpay-webhook, not here — this
/// only drops the cached "is it locked" answer and forwards into the
/// course. It shows a brief spinner rather than resolving in a redirect
/// callback so the provider invalidation happens once, in a normal
/// lifecycle, instead of as a side effect during routing.
class PaymentSuccessScreen extends ConsumerStatefulWidget {
  final String? courseId;

  const PaymentSuccessScreen({super.key, this.courseId});

  @override
  ConsumerState<PaymentSuccessScreen> createState() =>
      _PaymentSuccessScreenState();
}

class _PaymentSuccessScreenState extends ConsumerState<PaymentSuccessScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _continue());
  }

  void _continue() {
    if (!mounted) return;

    final courseId = widget.courseId;
    if (courseId == null || courseId.isEmpty) {
      context.go('/courses');
      return;
    }

    ref.invalidate(coursesProvider);
    ref.invalidate(courseDetailProvider(courseId));

    // go(), not push(): this screen is a waypoint, so it must not sit in
    // the back stack for the user to land on again.
    context.go('/course/$courseId');
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppTheme.background,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: AppTheme.sage, strokeWidth: 2),
            SizedBox(height: 16),
            Text(
              'Unlocking your course…',
              style: TextStyle(fontSize: 14, color: AppTheme.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}
