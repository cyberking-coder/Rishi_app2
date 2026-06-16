import '../entities/registered_device.dart';
import '../entities/subscription_summary.dart';
import '../entities/user_profile.dart';

abstract class ProfileRepository {
  Future<UserProfile> getProfile();

  /// Null if the user has never had a subscription row (free tier).
  Future<SubscriptionSummary?> getActiveSubscription();

  /// Devices ever registered for the account (the device-lock model keeps
  /// only one `is_active` at a time, but history is retained).
  Future<List<RegisteredDevice>> getDevices();

  /// This installation's device fingerprint, used to highlight the
  /// "current device" entry in the device list.
  Future<String> getCurrentDeviceFingerprint();
}
