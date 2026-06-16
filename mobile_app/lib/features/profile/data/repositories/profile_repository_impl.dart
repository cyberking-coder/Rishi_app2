import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/device/device_info_service.dart';
import '../../domain/entities/registered_device.dart';
import '../../domain/entities/subscription_summary.dart';
import '../../domain/entities/user_profile.dart';
import '../../domain/repositories/profile_repository.dart';
import '../datasources/profile_remote_datasource.dart';

class ProfileRepositoryImpl implements ProfileRepository {
  final ProfileRemoteDataSource _remote;
  final DeviceInfoService _deviceInfoService;
  final SupabaseClient _client;

  ProfileRepositoryImpl(this._remote, this._deviceInfoService, this._client);

  @override
  Future<UserProfile> getProfile() async {
    final row = await _remote.getProfileRow();
    final email = _client.auth.currentUser?.email ?? '';
    return UserProfile.fromMap(row, email: email);
  }

  @override
  Future<SubscriptionSummary?> getActiveSubscription() async {
    final row = await _remote.getLatestSubscriptionRow();
    if (row == null) return null;
    return SubscriptionSummary.fromMap(row);
  }

  @override
  Future<List<RegisteredDevice>> getDevices() async {
    final rows = await _remote.getDeviceRows();
    return rows.map(RegisteredDevice.fromMap).toList();
  }

  @override
  Future<String> getCurrentDeviceFingerprint() async {
    final profile = await _deviceInfoService.getDeviceProfile();
    return profile.fingerprint;
  }
}
