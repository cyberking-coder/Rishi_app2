/// How a member reaches a human.
///
/// ─────────────────────────────────────────────────────────────────────
///  KEEP IN SYNC WITH admin/src/lib/legal.ts
/// ─────────────────────────────────────────────────────────────────────
///  The same address and number are published on the public policy
///  pages, and Razorpay checks that a reachable contact exists and
///  matches the account. Two copies is two chances for one to go stale,
///  and the one that goes stale is always the one nobody is looking at
///  — which, for most of this app's life, is this one.
///
///  If either value changes there, change it here.
/// ─────────────────────────────────────────────────────────────────────
library;

class SupportConfig {
  const SupportConfig._();

  static const email = 'ar.happinessmovement@gmail.com';

  /// E.164, no spaces. Used to build `tel:` and `wa.me` links, neither of
  /// which tolerates the spacing a human would write.
  static const phoneE164 = '+917373738391';

  /// The same number as a person would read it.
  static const phoneDisplay = '+91 73737 38391';

  /// Indian working hours, stated plainly so nobody sits waiting for a
  /// reply at midnight assuming it is coming.
  static const hours = 'Mon–Sat, 10am–6pm IST';
}
