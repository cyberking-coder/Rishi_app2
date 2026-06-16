import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import '../crypto/file_crypto.dart';

/// One registered, playable offline file.
class _ProxyEntry {
  final File file;
  final DownloadCipherKey key;
  final String mimeType;
  _ProxyEntry(this.file, this.key, this.mimeType);
}

/// A loopback-only HTTP server that decrypts offline files on the fly and
/// serves them to the platform media players (`video_player` /
/// `just_audio`), which can only consume a URL or a plaintext file.
///
/// Why this exists: we never want a decrypted file to touch disk (it could
/// be copied/shared), and the media players can't decrypt themselves. So
/// we hold the plaintext only in memory, streamed over `127.0.0.1`, gated
/// by a per-session random token so no other app/process can request it.
/// Full HTTP Range support lets the player seek.
class LocalDecryptingProxy {
  HttpServer? _server;
  final Map<String, _ProxyEntry> _entries = {};
  late final String _sessionToken;

  static const _chunkSize = 64 * 1024;

  Future<void> start() async {
    if (_server != null) return;
    _sessionToken = _randomToken();
    // Bind to loopback only — unreachable from outside the device.
    _server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    _server!.listen(_handle);
  }

  /// Registers a decrypted view of [file] and returns the URL to play.
  /// The path embeds the per-session token; the id identifies the entry.
  Uri register(String id, File file, DownloadCipherKey key, String mimeType) {
    _entries[id] = _ProxyEntry(file, key, mimeType);
    final port = _server!.port;
    return Uri.parse('http://127.0.0.1:$port/$_sessionToken/$id');
  }

  void unregister(String id) => _entries.remove(id);

  Future<void> _handle(HttpRequest request) async {
    final segments = request.uri.pathSegments;
    // Reject anything without the session token or a known entry.
    if (segments.length != 2 ||
        segments[0] != _sessionToken ||
        !_entries.containsKey(segments[1])) {
      request.response.statusCode = HttpStatus.notFound;
      await request.response.close();
      return;
    }

    final entry = _entries[segments[1]]!;
    final totalLength = await entry.file.length();

    final range = _parseRange(request.headers.value(HttpHeaders.rangeHeader),
        totalLength);
    final start = range?.start ?? 0;
    final end = range?.end ?? (totalLength - 1);
    final length = end - start + 1;

    final response = request.response;
    response.headers
      ..set(HttpHeaders.acceptRangesHeader, 'bytes')
      ..set(HttpHeaders.contentTypeHeader, entry.mimeType)
      ..set(HttpHeaders.contentLengthHeader, length.toString());

    if (range != null) {
      response.statusCode = HttpStatus.partialContent;
      response.headers.set(
        HttpHeaders.contentRangeHeader,
        'bytes $start-$end/$totalLength',
      );
    } else {
      response.statusCode = HttpStatus.ok;
    }

    if (request.method == 'HEAD') {
      await response.close();
      return;
    }

    final transformer = CtrTransformer.atOffset(entry.key, start);
    final raf = await entry.file.open();
    try {
      await raf.setPosition(start);
      var remaining = length;
      while (remaining > 0) {
        final toRead = min(_chunkSize, remaining);
        final encrypted = await raf.read(toRead);
        if (encrypted.isEmpty) break;
        response.add(transformer.process(Uint8List.fromList(encrypted)));
        remaining -= encrypted.length;
      }
      await response.flush();
    } catch (_) {
      // Client disconnected mid-stream (e.g. seek) — expected, ignore.
    } finally {
      await raf.close();
      await response.close();
    }
  }

  ({int start, int end})? _parseRange(String? header, int totalLength) {
    if (header == null || !header.startsWith('bytes=')) return null;
    final spec = header.substring(6).split(',').first.trim();
    final parts = spec.split('-');
    if (parts.isEmpty) return null;

    final startStr = parts[0];
    final endStr = parts.length > 1 ? parts[1] : '';

    if (startStr.isEmpty) {
      // Suffix range: bytes=-N (last N bytes).
      if (endStr.isEmpty) return null;
      final n = int.parse(endStr);
      return (start: (totalLength - n).clamp(0, totalLength - 1), end: totalLength - 1);
    }

    final start = int.parse(startStr);
    final end = endStr.isEmpty ? totalLength - 1 : int.parse(endStr);
    if (start > end || start >= totalLength) return null;
    return (start: start, end: min(end, totalLength - 1));
  }

  String _randomToken() {
    final rnd = Random.secure();
    return List.generate(24, (_) => rnd.nextInt(256))
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join();
  }

  Future<void> dispose() async {
    _entries.clear();
    await _server?.close(force: true);
    _server = null;
  }
}
