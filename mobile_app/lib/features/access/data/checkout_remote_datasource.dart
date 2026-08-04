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
      // Include what the function actually said. The usual cause is
      // mint-checkout-token not having been redeployed with course
      // support, which reports as "plan_id is required" — useless if
      // it's swallowed into a generic retry message.
      final detail = response.data is Map
          ? (response.data as Map)['error'] ?? response.data
          : response.data;
      throw Exception('Checkout failed (${response.status}): $detail');
    }

    final token = (response.data as Map)['token'] as String;
    return Uri.parse('$checkoutBaseUrl/checkout/$courseId?token=$token');
  }

  /// Mints a checkout link for a seat at a paid live session.
  ///
  /// The session is the thing being sold — the pop-up that advertises it
  /// only points here, so there is one price in one place rather than an
  /// advert and an event that have to be kept in step by hand.
  Future<Uri> getSessionCheckoutUrl(String sessionId) async {
    final response = await _client.functions.invoke(
      'mint-checkout-token',
      body: {'live_session_id': sessionId},
    );

    if (response.status != 200) {
      final detail = response.data is Map
          ? (response.data as Map)['error'] ?? response.data
          : response.data;
      throw Exception('Registration failed (${response.status}): $detail');
    }

    final token = (response.data as Map)['token'] as String;
    return Uri.parse('$checkoutBaseUrl/checkout/$sessionId?token=$token');
  }
}
