import 'package:flutter_test/flutter_test.dart';
import 'package:meditation_app/features/auth/presentation/widgets/auth_validators.dart';

void main() {
  group('validateEmail', () {
    test('accepts a normal address (trimmed)', () {
      expect(validateEmail('  user@example.com '), isNull);
    });
    test('rejects empty and malformed', () {
      expect(validateEmail(''), 'Email is required');
      expect(validateEmail(null), 'Email is required');
      expect(validateEmail('notanemail'), isNotNull);
      expect(validateEmail('a@b'), isNotNull);
      expect(validateEmail('a b@c.com'), isNotNull);
    });
  });

  group('validatePasswordRequired (login)', () {
    test('only requires non-empty', () {
      expect(validatePasswordRequired('x'), isNull);
      expect(validatePasswordRequired('short'), isNull);
      expect(validatePasswordRequired(''), 'Password is required');
      expect(validatePasswordRequired(null), 'Password is required');
    });
  });

  group('validateNewPassword (signup)', () {
    test('accepts letter+digit+symbol, >=8', () {
      expect(validateNewPassword('Abcdef1!'), isNull);
    });
    test('rejects too short', () {
      expect(validateNewPassword('Ab1!'), 'Password must be at least 8 characters');
    });
    test('rejects missing character classes', () {
      expect(validateNewPassword('abcdefgh'), isNotNull); // no digit/symbol
      expect(validateNewPassword('abcdefg1'), isNotNull); // no symbol
      expect(validateNewPassword('12345678!'), isNotNull); // no letter
    });
    test('rejects empty', () {
      expect(validateNewPassword(''), 'Password is required');
      expect(validateNewPassword(null), 'Password is required');
    });
  });
}
