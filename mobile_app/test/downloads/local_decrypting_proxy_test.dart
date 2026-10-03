import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:meditation_app/features/downloads/data/crypto/file_crypto.dart';
import 'package:meditation_app/features/downloads/data/net/local_decrypting_proxy.dart';

/// Regression tests for the offline playback proxy.
///
/// The bug these lock in: every audio download was served as audio/mpeg,
/// so M4A/AAC files (served fine as MP3's sibling container) were rejected
/// by iOS AVPlayer offline with -11800 while MP3s played. The proxy now
/// sniffs the real container from the decrypted header and serves the
/// correct Content-Type plus a matching URL extension.
void main() {
  // Deterministic key/iv so the round-trip is reproducible.
  final key = DownloadCipherKey(
    Uint8List.fromList(List<int>.generate(32, (i) => i)),
    Uint8List.fromList(List<int>.generate(16, (i) => 255 - i)),
  );

  late Directory tmp;
  late LocalDecryptingProxy proxy;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('proxy_test');
    proxy = LocalDecryptingProxy();
  });

  tearDown(() async {
    await proxy.dispose();
    if (tmp.existsSync()) await tmp.delete(recursive: true);
  });

  /// Writes [plaintext] encrypted with [key] to a temp file, as the
  /// download pipeline would.
  Future<File> encryptedFile(String name, Uint8List plaintext) async {
    final enc = CtrTransformer.atOffset(key, 0).process(plaintext);
    final f = File('${tmp.path}/$name');
    await f.writeAsBytes(enc, flush: true);
    return f;
  }

  Uint8List withHeader(List<int> header, {int totalLen = 4096}) {
    final b = Uint8List(totalLen);
    for (var i = 0; i < header.length; i++) {
      b[i] = header[i];
    }
    // Fill the remainder with a recognisable pattern.
    for (var i = header.length; i < totalLen; i++) {
      b[i] = i % 251;
    }
    return b;
  }

  Future<HttpClientResponse> get(Uri uri, {String? range}) async {
    final client = HttpClient();
    final req = await client.getUrl(uri);
    if (range != null) req.headers.set(HttpHeaders.rangeHeader, range);
    final res = await req.close();
    return res;
  }

  test('M4A download declared as audio/mpeg is served as audio/mp4 (.m4a)',
      () async {
    // 0x00000020 box size, then 'ftyp' — the standard MP4/M4A header.
    final plaintext = withHeader(
      [0x00, 0x00, 0x00, 0x20, 0x66, 0x74, 0x79, 0x70], // ....ftyp
    );
    final file = await encryptedFile('chakras.enc', plaintext);

    // Declared type is the OLD wrong one the download pipeline passes.
    final uri = await proxy.register('audio_chakras_1', file, key, 'audio/mpeg');

    expect(uri.path.endsWith('.m4a'), isTrue,
        reason: 'URL should carry an .m4a extension hint for AVPlayer');

    final res = await get(uri);
    expect(res.headers.contentType?.mimeType, 'audio/mp4');

    final bytes = await _collect(res);
    expect(bytes, equals(plaintext),
        reason: 'proxy must decrypt back to the original plaintext');
  });

  test('MP3 download is served as audio/mpeg (.mp3)', () async {
    final plaintext = withHeader([0x49, 0x44, 0x33, 0x04]); // 'ID3'
    final file = await encryptedFile('healing.enc', plaintext);

    final uri = await proxy.register('audio_healing_1', file, key, 'audio/mpeg');

    expect(uri.path.endsWith('.mp3'), isTrue);
    final res = await get(uri);
    expect(res.headers.contentType?.mimeType, 'audio/mpeg');
    expect(await _collect(res), equals(plaintext));
  });

  test('range request returns the decrypted slice', () async {
    final plaintext = withHeader(
      [0x00, 0x00, 0x00, 0x20, 0x66, 0x74, 0x79, 0x70],
      totalLen: 2048,
    );
    final file = await encryptedFile('range.enc', plaintext);
    final uri = await proxy.register('audio_range_1', file, key, 'audio/mpeg');

    final res = await get(uri, range: 'bytes=100-199');
    expect(res.statusCode, HttpStatus.partialContent);
    final bytes = await _collect(res);
    expect(bytes.length, 100);
    expect(bytes, equals(plaintext.sublist(100, 200)),
        reason: 'CTR decryption must be correct at a non-zero offset');
  });
}

Future<Uint8List> _collect(HttpClientResponse res) async {
  final out = <int>[];
  await for (final chunk in res) {
    out.addAll(chunk);
  }
  return Uint8List.fromList(out);
}
