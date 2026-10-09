import 'dart:async';
import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart' show AuthException;

/// Whether [error] is a transient network/IO failure that must NOT be logged
/// to Crashlytics as a FATAL crash. The app recovers from all of these, so
/// recording them as fatal only inflates the crash rate and buries real
/// crashes.
///
/// It covers bare IO types AND wrapped ones — the case that keeps recurring is
/// Supabase's background token-refresh timer throwing an
/// `AuthRetryableFetchException` around a `SocketException: Failed host lookup`
/// when the device is offline. gotrue marks that retryable and retries it
/// itself; the app keeps running. The message-substring fallback catches such
/// wrappers whatever their concrete type.
bool isNonFatalError(Object error) {
  if (error is SocketException ||
      error is HttpException ||
      error is HandshakeException ||
      error is TimeoutException) {
    return true;
  }
  // A retryable auth-fetch failure (network, not credentials). Checked via the
  // base AuthException type + the retryable marker in its string form, so it
  // holds across gotrue versions without depending on the exact subclass name.
  if (error is AuthException &&
      error.toString().toLowerCase().contains('retryable')) {
    return true;
  }
  final s = error.toString().toLowerCase();
  return s.contains('failed host lookup') ||
      s.contains('no address associated with hostname') ||
      s.contains('socketexception') ||
      s.contains('clientexception') ||
      s.contains('connection closed') ||
      s.contains('connection reset') ||
      s.contains('connection abort') ||
      s.contains('network is unreachable') ||
      s.contains('timed out') ||
      s.contains('handshakeexception');
}
