import '../../../../core/errors/auth_failure.dart';

/// Maps a playback failure to a short, honest message.
///
/// The play path throws typed [AuthFailure]s — device lock, expired access,
/// premium — which were previously all shown as "Couldn't play this track.
/// Check your connection", hiding the real cause. The most common real cause
/// is a device reset: an admin "reset all devices" leaves a still-logged-in
/// session with no active device row, so the license is refused. Telling the
/// user "check your connection" for that cost real diagnosis time.
String playbackErrorMessage(Object error) {
  if (error is AuthFailure) {
    switch (error.type) {
      case AuthFailureType.deviceLocked:
        return 'This account is active on another device. Log out and back in '
            'on this device to play here.';
      case AuthFailureType.accessExpired:
        return 'Your access has ended. Please renew to keep listening.';
      case AuthFailureType.premiumRequired:
        return 'This is premium content. Unlock access to play it.';
      case AuthFailureType.network:
        return "Couldn't play this track. Check your connection and try again.";
      default:
        // 'No active device registered' / 'Not logged in' are unknown-typed
        // but are really the device case — a device reset leaves a logged-in
        // session with no active device row.
        if (error.message.toLowerCase().contains('device')) {
          return 'This device needs to be re-registered. Log out and back in '
              'on this device to play here.';
        }
        return "Couldn't play this track. Please try again.";
    }
  }
  return "Couldn't play this track. Check your connection and try again.";
}
