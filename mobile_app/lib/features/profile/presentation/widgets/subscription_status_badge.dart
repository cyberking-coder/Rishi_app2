import 'package:flutter/material.dart';

import '../../../../app/theme/app_theme.dart';
import '../../domain/entities/subscription_summary.dart';

/// Shows the plan name + a colored status pill (active/trialing = green,
/// past_due = amber, canceled/expired = red, free = grey).
class SubscriptionStatusBadge extends StatelessWidget {
  final SubscriptionSummary? subscription;

  const SubscriptionStatusBadge({super.key, this.subscription});

  @override
  Widget build(BuildContext context) {
    final sub = subscription;
    if (sub == null) {
      return _row(
        planName: 'Free plan',
        statusLabel: 'No active subscription',
        color: AppTheme.textSecondary,
      );
    }

    final color = switch (sub.status) {
      'active' || 'trialing' => Colors.greenAccent,
      'past_due' => Colors.amberAccent,
      _ => Colors.redAccent,
    };

    final statusLabel = sub.cancelAtPeriodEnd && sub.isActive
        ? 'Active — cancels ${_formatDate(sub.currentPeriodEnd)}'
        : sub.isActive
            ? 'Active — renews ${_formatDate(sub.currentPeriodEnd)}'
            : sub.status[0].toUpperCase() + sub.status.substring(1);

    return _row(planName: sub.planName, statusLabel: statusLabel, color: color);
  }

  Widget _row({
    required String planName,
    required String statusLabel,
    required Color color,
  }) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(planName,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text(statusLabel,
                  style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
            ],
          ),
        ),
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
      ],
    );
  }

  String _formatDate(DateTime? date) {
    if (date == null) return '';
    return '${date.day}/${date.month}/${date.year}';
  }
}
