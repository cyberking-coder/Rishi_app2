import 'package:supabase_flutter/supabase_flutter.dart';

import '../errors/auth_failure.dart';
import 'device_info_service.dart';

/// Resolves the caller's currently-active device id for a playback-license
/// request, re-registering this device if the active row has gone missing.
///
/// The one-device lock keeps a single `is_active` row in `devices` per user.
/// That row can legitimately become inactive while the user stays signed in —
/// an admin "reset device", or a registration that never stuck (e.g. the
/// `register_device` call at login failed transiently). When that happens the
/// old code threw "No active device registered" and the only cure was a full
/// sign-out/sign-in; a "Try again" button did nothing because nothing
/// re-registered the device.
///
/// This heals that in place: when no active device is found, it re-registers
/// THIS device. `register_device` reactivates it when no other device is
/// active, or raises DEVICE_LOCKED when the account is genuinely active on a
/// different device — which is surfaced as the correct "active elsewhere"
/// message instead of the misleading "no active device". The one-device lock
/// is preserved: a device that was correctly blocked has no session and never
/// reaches this path.
Future<String> resolveActiveDeviceId(
  SupabaseClient client,
  DeviceInfoService deviceInfo,
) async {
  final userId = client.auth.currentUser?.id;
  if (userId == null) throw AuthFailure.unknown('Not logged in');

  final existing = await client
      .from('devices')
      .select('id')
      .eq('user_id', userId)
      .eq('is_active', true)
      .maybeSingle();
  if (existing != null) return existing['id'] as String;

  // No active device — try to re-register this one.
  final profile = await deviceInfo.getDeviceProfile();
  try {
    final registered = await client.rpc('register_device', params: {
      'p_device_fingerprint': profile.fingerprint,
      'p_device_name': profile.name,
      'p_platform': profile.platform,
    });
    final id = registered is Map ? registered['id'] as String? : null;
    if (id != null) return id;
  } on PostgrestException catch (e) {
    if (e.hint == 'DEVICE_LOCKED' ||
        e.message.contains('already active on another device')) {
      throw AuthFailure.deviceLocked();
    }
    rethrow;
  }

  // Fall back to re-reading, in case the RPC shape wasn't a row map.
  final again = await client
      .from('devices')
      .select('id')
      .eq('user_id', userId)
      .eq('is_active', true)
      .maybeSingle();
  if (again != null) return again['id'] as String;

  throw AuthFailure.unknown('No active device registered');
}
