import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:meditation_app/core/errors/error_classification.dart';

/// Guards the Crashlytics fatal/non-fatal split. These transient network
/// failures must never be logged as fatal crashes (they recover and only
/// inflate the crash rate). Includes the exact wrapped message from the
/// real crash (Supabase background token refresh failing a DNS lookup
/// offline) that slipped through the type-only check.
void main() {
  group('non-fatal (network / IO, must NOT be fatal)', () {
    test('raw SocketException', () {
      expect(isNonFatalError(const SocketException('Failed host lookup')),
          isTrue);
    });

    test('TimeoutException', () {
      expect(isNonFatalError(TimeoutException('timed out')), isTrue);
    });

    test('the real crash: AuthRetryableFetchException wrapping a DNS failure',
        () {
      // Verbatim from the Crashlytics report.
      final e = Exception(
        "AuthRetryableFetchException(message: ClientException with "
        "SocketException: Failed host lookup: "
        "'gzcanqovqirarnculqjq.supabase.co' (OS Error: No address associated "
        "with hostname, errno = 7), "
        "uri=https://gzcanqovqirarnculqjq.supabase.co/auth/v1/token"
        "?grant_type=refresh_token, statusCode: null)",
      );
      expect(isNonFatalError(e), isTrue);
    });

    test('other wrapped connection failures', () {
      expect(isNonFatalError(Exception('Connection closed while receiving data')),
          isTrue);
      expect(isNonFatalError(Exception('Connection reset by peer')), isTrue);
      expect(
          isNonFatalError(Exception('HandshakeException: handshake error')),
          isTrue);
    });
  });

  group('fatal (real bugs, MUST stay fatal)', () {
    test('a null-cast / type error', () {
      expect(isNonFatalError(TypeError()), isFalse);
    });

    test('a StateError', () {
      expect(isNonFatalError(StateError('bad state')), isFalse);
    });

    test('a plain unexpected exception', () {
      expect(isNonFatalError(Exception('something unexpected broke')), isFalse);
    });
  });
}
