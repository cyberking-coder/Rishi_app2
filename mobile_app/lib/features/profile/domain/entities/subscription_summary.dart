/// The user's most relevant subscription row, or null if they've never
/// subscribed (treated as the free tier in the UI).
class SubscriptionSummary {
  final String planName;
  final String status; // trialing | active | past_due | canceled | expired
  final DateTime? currentPeriodEnd;
  final bool cancelAtPeriodEnd;

  const SubscriptionSummary({
    required this.planName,
    required this.status,
    this.currentPeriodEnd,
    this.cancelAtPeriodEnd = false,
  });

  bool get isActive => status == 'active' || status == 'trialing';

  factory SubscriptionSummary.fromMap(Map<String, dynamic> map) {
    final plan = map['subscription_plans'] as Map<String, dynamic>?;
    return SubscriptionSummary(
      planName: plan?['name'] as String? ?? 'Unknown plan',
      status: map['status'] as String? ?? 'active',
      currentPeriodEnd:
          DateTime.tryParse(map['current_period_end'] as String? ?? ''),
      cancelAtPeriodEnd: map['cancel_at_period_end'] as bool? ?? false,
    );
  }
}
