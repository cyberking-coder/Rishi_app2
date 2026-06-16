import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path_provider/path_provider.dart';

import '../crypto/file_crypto.dart';

/// Owns *where* and *how secretly* offline files are stored.
///
/// Files: app-private support directory (Android internal app storage /
/// iOS Library/Application Support). This location is NOT scanned by the
/// media store and is NOT visible in the gallery or a file-manager app,
/// and other apps cannot read it. We also use a `.enc` extension so no
/// media indexer treats the bytes as playable media.
///
/// Keys: the per-file AES key lives only in [FlutterSecureStorage]
/// (Android Keystore / iOS Keychain), never in the file or the manifest.
/// The (non-secret) IV is co-located so we can rebuild the cipher.
class SecureDownloadStorage {
  SecureDownloadStorage({FlutterSecureStorage? secureStorage})
      : _secureStorage = secureStorage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(encryptedSharedPreferences: true),
            );

  final FlutterSecureStorage _secureStorage;
  Directory? _dir;

  static const _keyPrefix = 'dl_key_';

  Future<Directory> _downloadsDir() async {
    if (_dir != null) return _dir!;
    final support = await getApplicationSupportDirectory();
    final dir = Directory('${support.path}/offline');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
      // Belt-and-braces for any Android OEM that scans app dirs.
      final noMedia = File('${dir.path}/.nomedia');
      if (!await noMedia.exists()) await noMedia.create();
    }
    _dir = dir;
    return dir;
  }

  Future<File> encryptedFile(String downloadId) async {
    final dir = await _downloadsDir();
    return File('${dir.path}/$downloadId.enc');
  }

  /// Generates and persists a fresh key for [downloadId]. The key half
  /// goes to the keystore; the IV is returned to the caller to persist in
  /// the (non-secret) manifest.
  Future<DownloadCipherKey> createKey(String downloadId) async {
    final cipherKey = DownloadCipherKey.generate();
    await _secureStorage.write(
      key: '$_keyPrefix$downloadId',
      value: base64Encode(cipherKey.key),
    );
    return cipherKey;
  }

  /// Reloads a previously-stored key, combined with the [iv] from the
  /// manifest. Returns null if the key is missing (e.g. wiped keystore).
  Future<DownloadCipherKey?> loadKey(String downloadId, Uint8List iv) async {
    final stored = await _secureStorage.read(key: '$_keyPrefix$downloadId');
    if (stored == null) return null;
    return DownloadCipherKey(base64Decode(stored), iv);
  }

  Future<void> deleteKey(String downloadId) =>
      _secureStorage.delete(key: '$_keyPrefix$downloadId');

  Future<void> deleteFile(String downloadId) async {
    final file = await encryptedFile(downloadId);
    if (await file.exists()) await file.delete();
  }

  /// Hard-removes both the encrypted bytes and the key.
  Future<void> purge(String downloadId) async {
    await deleteFile(downloadId);
    await deleteKey(downloadId);
  }
}
