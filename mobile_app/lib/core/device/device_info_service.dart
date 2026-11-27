import 'dart:io';

import 'package:crypto/crypto.dart' as crypto;
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path_provider/path_provider.dart';

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

    // The fingerprint is the durable per-install salt ALONE — not any OS
    // build property. It used to mix in Android's Build.ID (info.id) and
    // serialNumber; Build.ID changes on every OS/security update, so the same
    // phone silently got a new fingerprint after an update and tripped the
    // one-device lock, which is why the team kept having to "reset all
    // devices" after a build. The salt is persisted in secure storage AND a
    // file (see _getOrCreateInstallationSalt), so it survives OS updates, app
    // updates and a Keystore wipe — the same phone keeps the same identity and
    // never needs a reset. Device name/platform are still read for display.
    if (Platform.isAndroid) {
      final info = await _deviceInfoPlugin.androidInfo;
      return DeviceProfile(
        fingerprint: _hash(salt),
        name: '${info.manufacturer} ${info.model}',
        platform: 'android',
      );
    }

    if (Platform.isIOS) {
      final info = await _deviceInfoPlugin.iosInfo;
      return DeviceProfile(
        fingerprint: _hash(salt),
        name: info.utsname.machine,
        platform: 'ios',
      );
    }

    throw UnsupportedError('Unsupported platform for device lock.');
  }

  /// The random salt that makes the device fingerprint stable for THIS
  /// install, so the same phone keeps the same identity across a
  /// logout/login and never needs an admin "reset device".
  ///
  /// Persisted in TWO places and recovered from either:
  ///   1. Secure storage (survives reinstall on iOS via the Keychain).
  ///   2. A plain file in the app support dir.
  /// The second copy matters on Android: the secure-storage Keystore blob
  /// can become unreadable (BAD_DECRYPT) and get wiped, which used to
  /// regenerate the salt and change the fingerprint — the same phone then
  /// looked like a new device and got locked out until a reset. Recovering
  /// the salt from the file keeps the fingerprint identical.
  Future<String> _getOrCreateInstallationSalt() async {
    String? salt;
    try {
      salt = await _secureStorage.read(key: _installationSaltKey);
    } catch (_) {
      // Keystore blob unreadable — fall through to the file copy.
    }
    salt ??= await _readSaltFile();
    salt ??= DateTime.now().microsecondsSinceEpoch.toString();

    // Write both copies so either can restore it later. Best-effort: a
    // failing store must never block playback or sign-in.
    try {
      await _secureStorage.write(key: _installationSaltKey, value: salt);
    } catch (_) {}
    await _writeSaltFile(salt);
    return salt;
  }

  Future<File> _saltFile() async {
    final dir = await getApplicationSupportDirectory();
    return File('${dir.path}/$_installationSaltKey');
  }

  Future<String?> _readSaltFile() async {
    try {
      final f = await _saltFile();
      if (!await f.exists()) return null;
      final raw = (await f.readAsString()).trim();
      return raw.isEmpty ? null : raw;
    } catch (_) {
      return null;
    }
  }

  Future<void> _writeSaltFile(String salt) async {
    try {
      final f = await _saltFile();
      await f.writeAsString(salt, flush: true);
    } catch (_) {}
  }

  String _hash(String input) =>
      crypto.sha256.convert(input.codeUnits).toString();
}

final deviceInfoServiceProvider = Provider<DeviceInfoService>((ref) {
  return DeviceInfoService();
});
