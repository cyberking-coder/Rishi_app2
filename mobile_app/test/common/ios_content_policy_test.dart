import 'package:flutter_test/flutter_test.dart';
import 'package:meditation_app/core/config/ios_content_policy.dart';

/// App Store Guideline 3.1.3(a) enforcement: admin-authored pop-up text that
/// reads as a price or a call to buy must be suppressed on iOS. Over-blocking
/// has a cost too (a hidden message), so the benign cases matter as much as
/// the violations.
void main() {
  group('violates (must be hidden on iOS)', () {
    for (final t in [
      'Register ₹499 for the workshop',
      'Join the live workshop — book now',
      'Only 1999/- today',
      'Rs. 1500 early bird',
      'Subscribe to unlock',
      'Limited seats available',
      'Enroll now',
      'Pay now to confirm',
      '\$20 USD',
      'Special discount inside',
    ]) {
      test('"$t"', () => expect(violatesIosContentPolicy(t), isTrue));
    }
  });

  group('allowed (safe to show)', () {
    for (final t in [
      'Good morning 🌅',
      'A 20 minute breathing session',
      'Day 3 of your journey',
      'Join us for today\'s meditation',
      'Watch now',
      'Start today',
      '',
      '   ',
    ]) {
      test('"$t"', () => expect(violatesIosContentPolicy(t), isFalse));
    }
    test('null is allowed', () => expect(violatesIosContentPolicy(null), isFalse));
  });

  test('anyViolates flags a set with one bad string', () {
    expect(
      anyViolatesIosContentPolicy(['Good morning', 'Register ₹499', null]),
      isTrue,
    );
    expect(
      anyViolatesIosContentPolicy(['Good morning', 'Day 3', null]),
      isFalse,
    );
  });
}
