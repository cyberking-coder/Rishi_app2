import 'dart:io';

import 'package:crypto/crypto.dart' as crypto;
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'device_profile.dart';

/// Builds a stable device fingerprint used by the backend's one-device
/// lock. Combines a hardware identifier with a locally-persisted random
/// salt (secure storage survives app reinstall on iOS via Keychain, so
/// the fingerprint stays stable across reinstalls on the same device).
class DeviceInfoService {
  DeviceInfoService({
    DeviceInfoPlugin? deviceInfoPlugin,
    FlutterSecureStorage? secureStorage,
  })  : _deviceInfoPlugin = deviceInfoPlugin ?? DeviceInfoPlugin(),
        _secureStorage = secureStorage ?? const FlutterSecureStorage();

  static const _installationSaltKey = 'device_installation_salt';

  final DeviceInfoPlugin _deviceInfoPlugin;
  final FlutterSecureStorage _secureStorage;

  Future<DeviceProfile> getDeviceProfile() async {
    final salt = await _getOrCreateInstallationSalt();

    if (Platform.isAndroid) {
      final info = await _deviceInfoPlugin.androidInfo;
      final rawId = '${info.id}-${info.serialNumber}-$salt';
      return DeviceProfile(
        fingerprint: _hash(rawId),
        name: '${info.manufacturer} ${info.model}',
        platform: 'android',
      );
    }

    if (Platform.isIOS) {
      final info = await _deviceInfoPlugin.iosInfo;
      final rawId = '${info.identifierForVendor}-$salt';
      return DeviceProfile(
        fingerprint: _hash(rawId),
        name: info.utsname.machine,
        platform: 'ios',
      );
    }

    throw UnsupportedError('Unsupported platform for device lock.');
  }

  Future<String> _getOrCreateInstallationSalt() async {
    final existing = await _secureStorage.read(key: _installationSaltKey);
    if (existing != null) return existing;

    final salt = DateTime.now().microsecondsSinceEpoch.toString();
    await _secureStorage.write(key: _installationSaltKey, value: salt);
    return salt;
  }

  String _hash(String input) =>
      crypto.sha256.convert(input.codeUnits).toString();
}

final deviceInfoServiceProvider = Provider<DeviceInfoService>((ref) {
  return DeviceInfoService();
});
