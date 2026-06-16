import 'dart:math';
import 'dart:typed_data';

import 'package:pointycastle/export.dart';

/// The AES-256 key + 128-bit IV used to encrypt one download. The key is
/// secret and lives only in the OS keystore; the IV is stored alongside
/// the metadata (an IV is not secret, but must be unique per key).
class DownloadCipherKey {
  final Uint8List key; // 32 bytes
  final Uint8List iv; // 16 bytes

  const DownloadCipherKey(this.key, this.iv);

  factory DownloadCipherKey.generate() {
    final rnd = Random.secure();
    Uint8List bytes(int n) =>
        Uint8List.fromList(List.generate(n, (_) => rnd.nextInt(256)));
    return DownloadCipherKey(bytes(32), bytes(16));
  }
}

/// Stateful AES-256-CTR (SIC) transformer that can be positioned at any
/// byte offset. CTR/SIC is a stream cipher whose keystream for block N
/// depends only on (IV + N), so we can start encrypting/decrypting from
/// an arbitrary offset — which is what makes both *resumable downloads*
/// and *seekable offline playback* possible.
///
/// CTR encryption and decryption are the identical XOR operation, so this
/// single class serves both the download path (encrypt) and the playback
/// proxy (decrypt).
class CtrTransformer {
  final SICStreamCipher _cipher;

  CtrTransformer._(this._cipher);

  /// Builds a transformer whose keystream is aligned to [byteOffset] in
  /// the logical (plaintext) stream. Pass 0 to start from the beginning.
  factory CtrTransformer.atOffset(DownloadCipherKey k, int byteOffset) {
    final blockIndex = byteOffset ~/ 16;
    final intraBlock = byteOffset % 16;

    final cipher = SICStreamCipher(AESEngine())
      ..init(
        true, // CTR is symmetric; the flag is irrelevant for SIC.
        ParametersWithIV<KeyParameter>(
          KeyParameter(k.key),
          _advanceIv(k.iv, blockIndex),
        ),
      );

    // Discard the keystream bytes that precede our offset within the
    // first block, so the cipher's internal position lines up exactly.
    if (intraBlock > 0) {
      cipher.process(Uint8List(intraBlock));
    }
    return CtrTransformer._(cipher);
  }

  /// Transforms [data] (encrypt or decrypt — same thing) and advances the
  /// internal position by [data].length. Call repeatedly for a stream.
  Uint8List process(Uint8List data) => _cipher.process(data);

  /// Returns iv treated as a 128-bit big-endian integer, plus [blocks].
  /// SIC increments the entire IV big-endian, so adding the block index
  /// reproduces exactly the counter state SIC would have reached.
  static Uint8List _advanceIv(Uint8List iv, int blocks) {
    final result = Uint8List.fromList(iv);
    var carry = blocks;
    for (var i = result.length - 1; i >= 0 && carry > 0; i--) {
      final sum = result[i] + (carry & 0xff);
      result[i] = sum & 0xff;
      carry = (carry >> 8) + (sum >> 8);
    }
    return result;
  }
}
