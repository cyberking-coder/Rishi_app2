import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/app_role.dart';
import '../../../core/device/device_info_service.dart';
import '../../../core/network/supabase_client_provider.dart';
import '../../access/application/access_providers.dart';
import '../../downloads/application/download_providers.dart';
import '../../downloads/domain/entities/download_status.dart';
import '../data/datasources/profile_remote_datasource.dart';
import '../data/repositories/profile_repository_impl.dart';
import '../domain/entities/registered_device.dart';
import '../domain/entities/subscription_summary.dart';
import '../domain/entities/user_profile.dart';
import '../domain/repositories/profile_repository.dart';

final profileRemoteDataSourceProvider = Provider<ProfileRemoteDataSource>((ref) {
  return ProfileRemoteDataSource(ref.watch(supabaseClientProvider));
});

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  return ProfileRepositoryImpl(
    ref.watch(profileRemoteDataSourceProvider),
    ref.watch(deviceInfoServiceProvider),
    ref.watch(supabaseClientProvider),
  );
});

final userProfileProvider = FutureProvider.autoDispose<UserProfile>((ref) {
  return ref.watch(profileRepositoryProvider).getProfile();
});

/// The current user's derived Free/Retreat/Admin role. Composes the
/// profile role and access-window state that are already fetched for the
/// Profile screen and access banner — no new network call. Not yet read by
/// any screen; available as infrastructure for future gating.
final appRoleProvider = FutureProvider.autoDispose<AppRole>((ref) async {
  final profile = await ref.watch(userProfileProvider.future);
  final access = await ref.watch(accessStateProvider.future);
  return resolveAppRole(role: profile.role, hasAccess: access.hasAccess);
});

final subscriptionSummaryProvider =
    FutureProvider.autoDispose<SubscriptionSummary?>((ref) {
  return ref.watch(profileRepositoryProvider).getActiveSubscription();
});

final registeredDevicesProvider =
    FutureProvider.autoDispose<List<RegisteredDevice>>((ref) {
  return ref.watch(profileRepositoryProvider).getDevices();
});

final currentDeviceFingerprintProvider =
    FutureProvider.autoDispose<String>((ref) {
  return ref.watch(profileRepositoryProvider).getCurrentDeviceFingerprint();
});

/// Global theme mode — toggled from the Settings sheet in ProfileScreen.
final themeModeProvider = StateProvider<ThemeMode>((ref) => ThemeMode.dark);

/// Count of fully-downloaded (playable offline) items, reactive to the
/// same download stream the Downloads screen uses.
final downloadsCountProvider = Provider.autoDispose<int>((ref) {
  final tasks = ref.watch(downloadTasksProvider).valueOrNull ??
      ref.watch(downloadRepositoryProvider).tasks;
  return tasks.where((t) => t.status == DownloadStatus.completed).length;
});
