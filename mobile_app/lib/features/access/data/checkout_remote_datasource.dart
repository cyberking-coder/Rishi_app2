import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/checkout_config.dart';

class NoActivePlanException implements Exception {}

/// Mints a signed checkout link for the active subscription plan, via the
/// mint-checkout-token edge function. The actual payment happens on an
/// external web page (never in-app) - see checkout_config.dart and
/// admin/src/app/checkout/[planId] on the web side.
class CheckoutRemoteDataSource {
  final SupabaseClient _client;

  CheckoutRemoteDataSource(this._client);

  Future<Uri> getCheckoutUrl() async {
    final plan = await _client
        .from('subscription_plans')
        .select('id')
        .eq('is_active', true)
        .limit(1)
        .maybeSingle();

    final planId = plan?['id'] as String?;
    if (planId == null) throw NoActivePlanException();

    final response = await _client.functions.invoke(
      'mint-checkout-token',
      body: {'plan_id': planId},
    );

    if (response.status != 200) {
      throw Exception('Could not start checkout. Please try again.');
    }

    final token = (response.data as Map)['token'] as String;
    return Uri.parse('$checkoutBaseUrl/checkout/$planId?token=$token');
  }

  /// Mints a checkout link for a single course. Courses are sold
  /// individually, so this targets a courses.id rather than a plan — the
  /// web page prices it from the course row.
  Future<Uri> getCourseCheckoutUrl(String courseId) async {
    final response = await _client.functions.invoke(
      'mint-checkout-token',
      body: {'course_id': courseId},
    );

    if (response.status != 200) {
      throw Exception('Could not start checkout. Please try again.');
    }

    final token = (response.data as Map)['token'] as String;
    return Uri.parse('$checkoutBaseUrl/checkout/$courseId?token=$token');
  }
}
