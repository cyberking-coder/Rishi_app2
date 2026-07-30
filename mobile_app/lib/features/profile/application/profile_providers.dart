import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/device/device_info_service.dart';
import '../../../core/network/supabase_client_provider.dart';
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
// The app ships a single light visual language now; AppTheme.dark()
// resolves to the same thing, so this just stops a stale 'dark'
// preference from meaning anything different.
final themeModeProvider = StateProvider<ThemeMode>((ref) => ThemeMode.light);

/// Count of fully-downloaded (playable offline) items, reactive to the
/// same download stream the Downloads screen uses.
final downloadsCountProvider = Provider.autoDispose<int>((ref) {
  final tasks = ref.watch(downloadTasksProvider).valueOrNull ??
      ref.watch(downloadRepositoryProvider).tasks;
  return tasks.where((t) => t.status == DownloadStatus.completed).length;
});
