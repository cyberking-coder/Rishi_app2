import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../app/theme/app_theme.dart';
import '../../../../core/config/purchase_config.dart';
import '../../../access/application/access_providers.dart';

/// Prompts to buy a single course.
///
/// Courses are sold individually, so this is separate from the
/// subscription lock dialog: the price shown is the course's own, and
/// checkout targets the course rather than the plan. Payment happens in
/// an external browser, never in-app — deliberately, to stay outside
/// Google's in-app purchase rules for digital content.
///
/// On iOS the price and the button are both gone and this is only an
/// explanation that the course is locked — see [kPurchaseUiEnabled].
/// The sheet still opens rather than the tap doing nothing, because a
/// locked lesson that silently ignores you reads as a broken app.
Future<void> showCoursePurchaseSheet(
  BuildContext context,
  WidgetRef ref, {
  required String courseId,
  required String courseTitle,
  required String priceLabel,
}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => _CoursePurchaseSheet(
      courseId: courseId,
      courseTitle: courseTitle,
      priceLabel: priceLabel,
    ),
  );
}

class _CoursePurchaseSheet extends ConsumerStatefulWidget {
  final String courseId;
  final String courseTitle;
  final String priceLabel;

  const _CoursePurchaseSheet({
    required this.courseId,
    required this.courseTitle,
    required this.priceLabel,
  });

  @override
  ConsumerState<_CoursePurchaseSheet> createState() =>
      _CoursePurchaseSheetState();
}

class _CoursePurchaseSheetState extends ConsumerState<_CoursePurchaseSheet> {
  bool _loading = false;
  String? _error;

  static const _fallback =
      'Please contact us and our team will help you get access:\n'
      'ar.happinessmovement@gmail.com';

  Future<void> _buy() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final url = await ref
          .read(checkoutRemoteDataSourceProvider)
          .getCourseCheckoutUrl(widget.courseId);
      final opened =
          await launchUrl(url, mode: LaunchMode.externalApplication);
      if (!opened) throw Exception('Could not open checkout');
      if (mounted) Navigator.pop(context);
    } catch (e) {
      // Show what actually failed. A blanket "something went wrong" here
      // hid a real, fixable cause (an edge function that hadn't been
      // redeployed) behind a message that suggested emailing support.
      if (mounted) {
        setState(() => _error = '$e\n\n$_fallback');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        22,
        18,
        22,
        22 + MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: BoxDecoration(
        gradient: AppTheme.clayFill(),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 38,
          height: 4,
          decoration: BoxDecoration(
            color: AppTheme.border,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(height: 20),

        Container(
          padding: const EdgeInsets.all(14),
          decoration: const BoxDecoration(
            color: AppTheme.sageSoft,
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.lock_outline_rounded,
              color: AppTheme.sage, size: 24),
        ),
        const SizedBox(height: 16),

        Text(
          widget.courseTitle,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            color: AppTheme.textPrimary,
            height: 1.3,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          kPurchaseUiEnabled
              ? 'Get lifetime access to every lesson in this course.'
              : kLockedContentMessage,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 13,
            color: AppTheme.textSecondary,
            height: 1.5,
          ),
        ),

        if (kPurchaseUiEnabled) ...[
          const SizedBox(height: 18),
          Text(
            widget.priceLabel,
            style: const TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.w800,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'One-time payment',
            style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
          ),
        ],

        if (_error != null) ...[
          const SizedBox(height: 14),
          Text(
            _error!,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 12.5,
              color: AppTheme.clay,
              height: 1.5,
            ),
          ),
        ],

        const SizedBox(height: 20),
        if (kPurchaseUiEnabled) ...[
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _loading ? null : _buy,
              child: _loading
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Get Access Now'),
            ),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: _loading ? null : () => Navigator.pop(context),
            child: const Text(
              'Not now',
              style: TextStyle(color: AppTheme.textSecondary),
            ),
          ),
        ] else
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ),
      ]),
    );
  }
}
