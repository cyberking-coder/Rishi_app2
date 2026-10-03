import 'package:flutter_test/flutter_test.dart';
import 'package:meditation_app/features/live/domain/entities/live_session.dart';

void main() {
  LiveSession at(DateTime starts, {int duration = 60, String status = 'scheduled', int? price, String currency = 'INR'}) =>
      LiveSession(
        id: 'l',
        title: 'Live',
        joinUrl: 'https://zoom',
        startsAt: starts,
        durationMinutes: duration,
        status: status,
        priceAmount: price,
        currency: currency,
      );

  group('fromMap', () {
    test('parses a full row and converts time to local', () {
      final s = LiveSession.fromMap({
        'id': 'l1',
        'title': 'Breathwork',
        'join_url': 'https://zoom/x',
        'starts_at': '2026-01-01T10:00:00Z',
        'duration_minutes': 45,
        'status': 'scheduled',
        'price_amount': 49900,
        'currency': 'INR',
        'seat_limit': 100,
      });
      expect(s.title, 'Breathwork');
      expect(s.durationMinutes, 45);
      expect(s.isPaid, isTrue);
      expect(s.seatLimit, 100);
    });

    test('applies defaults for a sparse row', () {
      final s = LiveSession.fromMap({'starts_at': '2026-01-01T10:00:00Z'});
      expect(s.title, 'Live session');
      expect(s.durationMinutes, 60);
      expect(s.status, 'scheduled');
      expect(s.isPaid, isFalse);
      expect(s.currency, 'INR');
    });
  });

  group('price label', () {
    test('free when null/zero', () {
      expect(at(DateTime(2026), price: null).isPaid, isFalse);
      expect(at(DateTime(2026), price: 0).priceLabel, '₹0');
    });
    test('whole and fractional rupees; non-INR prefix', () {
      expect(at(DateTime(2026), price: 50000).priceLabel, '₹500');
      expect(at(DateTime(2026), price: 49950).priceLabel, '₹499.50');
      expect(at(DateTime(2026), price: 1000, currency: 'USD').priceLabel, 'USD 10');
    });
  });

  group('time state', () {
    test('isLiveNow true within the 10-min early window', () {
      final s = at(DateTime.now().subtract(const Duration(minutes: 5)));
      expect(s.isLiveNow, isTrue);
      expect(s.isOver, isFalse);
    });
    test('not live before the early window', () {
      final s = at(DateTime.now().add(const Duration(hours: 2)));
      expect(s.isLiveNow, isFalse);
    });
    test('over after end', () {
      final s = at(DateTime.now().subtract(const Duration(hours: 3)), duration: 30);
      expect(s.isOver, isTrue);
      expect(s.isLiveNow, isFalse);
    });
    test('cancelled is never live', () {
      final s = at(DateTime.now().subtract(const Duration(minutes: 5)), status: 'cancelled');
      expect(s.isCancelled, isTrue);
      expect(s.isLiveNow, isFalse);
    });
  });
}
