import 'package:flutter_test/flutter_test.dart';
import 'package:meditation_app/features/auth/data/offline_session_store.dart';
import 'package:meditation_app/features/auth/domain/entities/app_access_mode.dart';

/// Locks the 3-state access model: online = identity, offline = time-boxed
/// local permission, signed-out = nothing. These guard the reinstall bug from
/// ever returning.
void main() {
  group('decideAccessMode', () {
    test('a live session is always online', () {
      expect(
        decideAccessMode(
          hasSession: true,
          hasOfflineIdentity: false,
          offlineStillValid: false,
          hasNetwork: false,
        ),
        AppAccessMode.authenticatedOnline,
      );
    });

    test('no session and no offline identity → signed out (the reinstall case)',
        () {
      // A fresh install: secure storage (session + offline token) is not
      // restored by Android backup, so there is no identity at all.
      expect(
        decideAccessMode(
          hasSession: false,
          hasOfflineIdentity: false,
          offlineStillValid: false,
          hasNetwork: true,
        ),
        AppAccessMode.signedOut,
      );
    });

    test('offline with a valid grace window → offline', () {
      expect(
        decideAccessMode(
          hasSession: false,
          hasOfflineIdentity: true,
          offlineStillValid: true,
          hasNetwork: false,
        ),
        AppAccessMode.authenticatedOffline,
      );
    });

    test('offline with an expired grace window → signed out', () {
      expect(
        decideAccessMode(
          hasSession: false,
          hasOfflineIdentity: true,
          offlineStillValid: false,
          hasNetwork: false,
        ),
        AppAccessMode.signedOut,
      );
    });

    test('online with identity but no session asks for a refresh first', () {
      expect(
        decideAccessMode(
          hasSession: false,
          hasOfflineIdentity: true,
          offlineStillValid: true,
          hasNetwork: true,
        ),
        AppAccessMode.resolving,
      );
    });

    group('after a refresh attempt (online, identity present)', () {
      AppAccessMode decide(RefreshOutcome outcome, {required bool valid}) =>
          decideAccessMode(
            hasSession: false,
            hasOfflineIdentity: true,
            offlineStillValid: valid,
            hasNetwork: true,
            refreshOutcome: outcome,
          );

      test('success → online', () {
        expect(decide(RefreshOutcome.success, valid: true),
            AppAccessMode.authenticatedOnline);
      });

      test('invalid refresh token → signed out, even if grace not expired', () {
        expect(decide(RefreshOutcome.invalid, valid: true),
            AppAccessMode.signedOut);
      });

      test('network error falls back to the grace window', () {
        expect(decide(RefreshOutcome.networkError, valid: true),
            AppAccessMode.authenticatedOffline);
        expect(decide(RefreshOutcome.networkError, valid: false),
            AppAccessMode.signedOut);
      });
    });
  });

  group('OfflineSession', () {
    test('isStillValid reflects the grace window', () {
      final now = DateTime(2026, 10, 4, 9);
      final s = OfflineSession(
        userId: 'u1',
        lastVerifiedAt: now,
        offlineAccessUntil: now.add(const Duration(days: 7)),
      );
      expect(s.isStillValid(now.add(const Duration(days: 6))), isTrue);
      expect(s.isStillValid(now.add(const Duration(days: 8))), isFalse);
    });

    test('json round-trips', () {
      final now = DateTime.utc(2026, 10, 4, 9);
      final s = OfflineSession(
        userId: 'u1',
        deviceId: 'd1',
        lastVerifiedAt: now,
        offlineAccessUntil: now.add(const Duration(days: 7)),
      );
      final back = OfflineSession.fromJson(s.toJson());
      expect(back, isNotNull);
      expect(back!.userId, 'u1');
      expect(back.deviceId, 'd1');
      expect(back.offlineAccessUntil, s.offlineAccessUntil);
    });

    test('a malformed/empty map parses to null, not a crash', () {
      expect(OfflineSession.fromJson({}), isNull);
      expect(OfflineSession.fromJson({'userId': 'u1'}), isNull); // missing dates
    });
  });
}
