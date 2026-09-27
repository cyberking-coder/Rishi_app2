import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// A durable "this device has an active login" flag, owned by the app.
///
/// It is set true the moment a real authenticated session is seen, and cleared
/// ONLY by an explicit sign-out (or account deletion). It is deliberately NOT
/// tied to Supabase's session state: on iOS, gotrue drops its persisted session
/// after the short access token expires while the device is offline and cannot
/// refresh — which made the app treat a downloaded-track listener as signed out
/// and bounce them to /login (and on to /home) mid-playback. The router reads
/// this flag so offline use can never be redirected for a token it simply
/// could not refresh.
///
/// Stored as a tiny PLAIN file (not flutter_secure_storage) on purpose: it
/// holds no secret, and an encrypted-store hiccup (the BadPadding class of bug)
/// must not make it unreadable and silently re-trigger the redirect.
class LoginFlagStore {
  File? _file;

  Future<File> _f() async {
    if (_file != null) return _file!;
    final dir = await getApplicationSupportDirectory();
    _file = File('${dir.path}/login_flag');
    return _file!;
  }

  /// Reads the flag. Any failure (missing file, read error) is "not logged
  /// in" — the safe default for a device that has never signed in.
  Future<bool> read() async {
    try {
      final f = await _f();
      if (!await f.exists()) return false;
      return (await f.readAsString()).trim() == '1';
    } catch (_) {
      return false;
    }
  }

  Future<void> set(bool value) async {
    try {
      final f = await _f();
      await f.writeAsString(value ? '1' : '0', flush: true);
    } catch (_) {
      // Best-effort. A failed write only means the hint may not persist across
      // a cold start; the in-memory flag still holds for this run.
    }
  }
}
