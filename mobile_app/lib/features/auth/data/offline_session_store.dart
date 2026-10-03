import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// A verified offline identity for this device — the replacement for the old
/// plain `loginFlag` boolean.
///
/// It is written ONLY after a real online authentication, and it records
/// *who* was verified, *which* device, *when*, and *until when* offline use
/// is allowed. Offline access is then "previously verified AND within the
/// grace period", never "a boolean survived".
class OfflineSession {
  final String userId;

  /// The device this installation was verified as. Null until device-lock is
  /// wired into verification (Phase 3); kept in the schema from day one.
  final String? deviceId;

  final DateTime lastVerifiedAt;

  /// Offline playback is allowed until this instant. Slid forward on every
  /// successful online verification.
  final DateTime offlineAccessUntil;

  const OfflineSession({
    required this.userId,
    required this.lastVerifiedAt,
    required this.offlineAccessUntil,
    this.deviceId,
  });

  /// Whether the offline grace period still covers [now] (defaults to now).
  bool isStillValid([DateTime? now]) =>
      (now ?? DateTime.now()).isBefore(offlineAccessUntil);

  Map<String, dynamic> toJson() => {
        'userId': userId,
        'deviceId': deviceId,
        'lastVerifiedAt': lastVerifiedAt.toIso8601String(),
        'offlineAccessUntil': offlineAccessUntil.toIso8601String(),
      };

  static OfflineSession? fromJson(Map<String, dynamic> json) {
    final userId = json['userId'] as String?;
    final verified = DateTime.tryParse(json['lastVerifiedAt'] as String? ?? '');
    final until = DateTime.tryParse(json['offlineAccessUntil'] as String? ?? '');
    if (userId == null || verified == null || until == null) return null;
    return OfflineSession(
      userId: userId,
      deviceId: json['deviceId'] as String?,
      lastVerifiedAt: verified,
      offlineAccessUntil: until,
    );
  }
}

/// Persists the [OfflineSession] in the OS secure store.
///
/// Secure storage on Android is EXCLUDED from Auto Backup (see
/// backup_rules.xml), so this offline identity shares the session's fate: a
/// reinstall starts with neither, which is exactly why the app must then show
/// login rather than a broken logged-in shell.
class OfflineSessionStore {
  OfflineSessionStore([FlutterSecureStorage? storage])
      : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;
  static const _key = 'offline_session_v1';

  /// Standard offline grace: downloads play for this long after the last
  /// successful online verification.
  static const grace = Duration(days: 7);

  Future<OfflineSession?> read() async {
    try {
      final raw = await _storage.read(key: _key);
      if (raw == null || raw.isEmpty) return null;
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return OfflineSession.fromJson(map);
    } catch (_) {
      // Unreadable (corrupt / keystore hiccup) → treat as no offline identity.
      return null;
    }
  }

  /// Records a fresh verification: now, and a grace window of [grace] from now.
  Future<OfflineSession> markVerified({
    required String userId,
    String? deviceId,
    DateTime? now,
  }) async {
    final ts = now ?? DateTime.now();
    final session = OfflineSession(
      userId: userId,
      deviceId: deviceId,
      lastVerifiedAt: ts,
      offlineAccessUntil: ts.add(grace),
    );
    try {
      await _storage.write(key: _key, value: jsonEncode(session.toJson()));
    } catch (_) {
      // Best-effort; the in-memory decision for this run still holds.
    }
    return session;
  }

  Future<void> clear() async {
    try {
      await _storage.delete(key: _key);
    } catch (_) {}
  }
}
