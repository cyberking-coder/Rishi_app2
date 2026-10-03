import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:meditation_app/features/downloads/data/crypto/file_crypto.dart';

/// Regression tests for the AES-256-CTR transformer that encrypts every
/// download and decrypts it for offline playback. The offset math is the
/// load-bearing part: resumable downloads and seekable offline playback both
/// start the cipher mid-stream, and if the keystream is off by even one byte
/// the file decrypts to garbage — which surfaces as "downloaded audio won't
/// play". These lock that behaviour in.
void main() {
  // Fixed key/iv so every run is deterministic.
  final key = DownloadCipherKey(
    Uint8List.fromList(List<int>.generate(32, (i) => (i * 7) % 256)),
    Uint8List.fromList(List<int>.generate(16, (i) => (i * 13) % 256)),
  );

  Uint8List plaintext(int n) =>
      Uint8List.fromList(List<int>.generate(n, (i) => (i * 31 + 5) % 256));

  test('encrypt then decrypt from 0 round-trips exactly', () {
    final data = plaintext(10000);
    final encrypted = CtrTransformer.atOffset(key, 0).process(data);
    expect(encrypted, isNot(equals(data)), reason: 'must actually encrypt');
    final decrypted = CtrTransformer.atOffset(key, 0).process(encrypted);
    expect(decrypted, equals(data));
  });

  test('decrypting a slice at an offset matches the whole-file decryption',
      () {
    final data = plaintext(20000);
    final whole = CtrTransformer.atOffset(key, 0).process(data);

    // Decrypt only bytes [7777, 12345) starting the cipher at that offset —
    // exactly what the playback proxy does for a Range request.
    const start = 7777;
    const end = 12345;
    final slice = CtrTransformer.atOffset(key, start)
        .process(Uint8List.sublistView(whole, start, end));
    expect(slice, equals(data.sublist(start, end)));
  });

  test('offset decryption is correct at many non-block-aligned boundaries',
      () {
    final data = plaintext(5000);
    final encrypted = CtrTransformer.atOffset(key, 0).process(data);

    // 16 = AES block size; test offsets around and across block boundaries.
    for (final start in [1, 15, 16, 17, 31, 33, 100, 1023, 1024, 4096, 4097]) {
      final dec = CtrTransformer.atOffset(key, start)
          .process(Uint8List.sublistView(encrypted, start));
      expect(dec, equals(data.sublist(start)),
          reason: 'offset $start must decrypt correctly');
    }
  });

  test('streaming in chunks equals one-shot (stateful advance)', () {
    final data = plaintext(8192);
    final oneShot = CtrTransformer.atOffset(key, 0).process(data);

    final streamer = CtrTransformer.atOffset(key, 0);
    final out = BytesBuilder();
    var i = 0;
    for (final chunk in [1, 15, 16, 100, 1000, 4096]) {
      final endIdx = (i + chunk).clamp(0, data.length);
      out.add(streamer.process(Uint8List.sublistView(data, i, endIdx)));
      i = endIdx;
    }
    if (i < data.length) out.add(streamer.process(Uint8List.sublistView(data, i)));
    expect(out.toBytes(), equals(oneShot));
  });

  test('generate() produces 32-byte key and 16-byte iv', () {
    final k = DownloadCipherKey.generate();
    expect(k.key.length, 32);
    expect(k.iv.length, 16);
    final k2 = DownloadCipherKey.generate();
    expect(k.key, isNot(equals(k2.key)), reason: 'keys must be random');
  });
}
