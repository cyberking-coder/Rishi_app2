import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Remembers which pop-up was shown on which day, so a Monday message
/// appears once on Monday rather than on every launch that Monday.
///
/// Without this, "show it on Monday" means "show it every time the app is
/// opened all Monday" — which is how a message people were glad to read
/// once becomes the reason they stop opening the app.
///
/// Keyed per pop-up and per IST date. Two pop-ups can therefore each be
/// seen once on a day they both match, and the record for a given pop-up
/// naturally expires when the date rolls over — nothing has to be swept.
class PopupSeenStore {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  static String _key(String popupId) => 'popup_seen_$popupId';

  /// True if this pop-up has already been shown on [dateKey].
  ///
  /// Fails open. If storage is unreadable the answer is "not seen", so a
  /// broken keystore shows the pop-up an extra time rather than
  /// suppressing it forever — the recoverable failure of the two.
  static Future<bool> wasSeen(String popupId, String dateKey) async {
    try {
      return await _storage.read(key: _key(popupId)) == dateKey;
    } catch (e) {
      debugPrint('Could not read pop-up history: $e');
      return false;
    }
  }

  static Future<void> markSeen(String popupId, String dateKey) async {
    try {
      await _storage.write(key: _key(popupId), value: dateKey);
    } catch (e) {
      debugPrint('Could not record pop-up as seen: $e');
    }
  }
}
