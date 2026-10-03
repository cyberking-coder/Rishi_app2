import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import '../crypto/file_crypto.dart';

/// One registered, playable offline file.
class _ProxyEntry {
  final File file;
  final DownloadCipherKey key;
  final String mimeType;

  /// The Content-Type actually served, resolved once by sniffing the
  /// decrypted file header (see [LocalDecryptingProxy._resolveContentType]).
  /// Null until first resolved, then cached for every later range request.
  String? resolvedMimeType;

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

  /// Not `late final`. It was, and that made a failed [start] permanent:
  /// assigning a `late final` twice throws, so any retry after a failed
  /// bind died on the assignment rather than on the thing that actually
  /// went wrong. Now the token is minted once and survives a retry.
  String? _sessionToken;

  static const _chunkSize = 64 * 1024;

  /// Binds the loopback server. Safe to call repeatedly: a no-op once
  /// running, and a genuine retry if a previous attempt failed.
  Future<void> start() async {
    if (_server != null) return;
    _sessionToken ??= _randomToken();
    // Bind to loopback only — unreachable from outside the device.
    _server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    _server!.listen(_handle);
  }

  /// Registers a decrypted view of [file] and returns the URL to play.
  /// The path embeds the per-session token; the id identifies the entry.
  ///
  /// Starts the server if it isn't running. Playback is the one moment
  /// the proxy is genuinely needed, so a bind that failed at launch gets
  /// another attempt here rather than making every offline file
  /// unplayable for the rest of the session.
  Future<Uri> register(
    String id,
    File file,
    DownloadCipherKey key,
    String mimeType,
  ) async {
    await start();
    final entry = _ProxyEntry(file, key, mimeType);
    _entries[id] = entry;
    final port = _server!.port;
    // Resolve the real type now (sniffs + caches) and put a matching file
    // extension on the URL. iOS AVPlayer decides an asset's type from the
    // URL extension as well as the Content-Type; an extension-less URL for
    // an M4A was enough to make it refuse the file with -11800 even once
    // the Content-Type was right. Ids contain no dots, so the extension is
    // recovered unambiguously on the way back in.
    final contentType = await _resolveContentType(entry);
    final ext = _extensionForMime(contentType);
    final suffix = ext != null ? '.$ext' : '';
    return Uri.parse('http://127.0.0.1:$port/${_sessionToken!}/$id$suffix');
  }

  void unregister(String id) => _entries.remove(id);

  Future<void> _handle(HttpRequest request) async {
    final segments = request.uri.pathSegments;
    // The last path segment is "<id>" or "<id>.<ext>"; ids carry no dots,
    // so strip a trailing extension to recover the entry key.
    final rawId = segments.length == 2 ? segments[1] : '';
    final dot = rawId.lastIndexOf('.');
    final entryId = dot > 0 ? rawId.substring(0, dot) : rawId;

    // Reject anything without the session token or a known entry.
    if (segments.length != 2 ||
        segments[0] != _sessionToken ||
        !_entries.containsKey(entryId)) {
      request.response.statusCode = HttpStatus.notFound;
      await request.response.close();
      return;
    }

    final entry = _entries[entryId]!;
    final totalLength = await entry.file.length();

    // Resolve the real Content-Type from the decrypted header rather than
    // trusting the type passed at download time. Audio uploads are a mix
    // of MP3 (audio/mpeg) and M4A/AAC (audio/mp4); every audio download was
    // previously announced as audio/mpeg, so M4A files handed to iOS
    // AVPlayer failed to play offline while the identical MP3 worked. This
    // also repairs files already on disk — nothing has to be re-downloaded.
    final contentType = await _resolveContentType(entry);

    final range = _parseRange(request.headers.value(HttpHeaders.rangeHeader),
        totalLength);
    final start = range?.start ?? 0;
    final end = range?.end ?? (totalLength - 1);
    final length = end - start + 1;

    final response = request.response;
    response.headers
      ..set(HttpHeaders.acceptRangesHeader, 'bytes')
      ..set(HttpHeaders.contentTypeHeader, contentType)
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

  /// The Content-Type to serve [entry], resolved once by decrypting and
  /// inspecting the first bytes of the file, then cached.
  ///
  /// Video downloads are always MP4 and keep their declared type. For
  /// audio, the declared type is ignored in favour of what the bytes say,
  /// because the download pipeline does not record which audio container
  /// was fetched (MP3 vs M4A/AAC) and announcing the wrong one is what
  /// stopped some downloaded tracks playing offline on iOS. Falls back to
  /// the declared type when the header is unrecognised or unreadable.
  Future<String> _resolveContentType(_ProxyEntry entry) async {
    final cached = entry.resolvedMimeType;
    if (cached != null) return cached;

    var resolved = entry.mimeType;
    if (entry.mimeType.startsWith('audio/')) {
      try {
        final raf = await entry.file.open();
        try {
          final encrypted = await raf.read(16);
          if (encrypted.isNotEmpty) {
            final header = CtrTransformer.atOffset(entry.key, 0)
                .process(Uint8List.fromList(encrypted));
            resolved = _sniffAudioMime(header) ?? entry.mimeType;
          }
        } finally {
          await raf.close();
        }
      } catch (_) {
        // Unreadable header — keep the declared type.
      }
    }

    entry.resolvedMimeType = resolved;
    return resolved;
  }

  /// The file extension AVPlayer expects for a given Content-Type, or null
  /// when there is no helpful one (the URL then carries no extension).
  String? _extensionForMime(String mime) => switch (mime) {
        'audio/mp4' => 'm4a',
        'audio/mpeg' => 'mp3',
        'audio/wav' => 'wav',
        'audio/flac' => 'flac',
        'audio/ogg' => 'ogg',
        'audio/aac' => 'aac',
        'video/mp4' => 'mp4',
        _ => null,
      };

  /// Identifies an audio container from its leading bytes, or null when it
  /// matches nothing known (so the caller keeps the declared type).
  String? _sniffAudioMime(Uint8List b) {
    if (b.length < 4) return null;

    String ascii(int i, int n) =>
        (i + n <= b.length) ? String.fromCharCodes(b.sublist(i, i + n)) : '';

    // ISO base-media (MP4/M4A/M4B/AAC-in-MP4): '....ftyp' at byte 4.
    if (ascii(4, 4) == 'ftyp') return 'audio/mp4';
    // ID3v2-tagged MP3.
    if (ascii(0, 3) == 'ID3') return 'audio/mpeg';
    // WAV.
    if (ascii(0, 4) == 'RIFF' && ascii(8, 4) == 'WAVE') return 'audio/wav';
    // FLAC.
    if (ascii(0, 4) == 'fLaC') return 'audio/flac';
    // Ogg.
    if (ascii(0, 4) == 'OggS') return 'audio/ogg';
    // Raw frame-sync formats all start 0xFF 0xEx. ADTS AAC uses 0xF1/0xF9
    // in the second byte; anything else in that range is an MPEG-audio
    // (MP3) frame. Check ADTS first — its sync also satisfies the MP3 mask.
    if (b[0] == 0xFF && (b[1] == 0xF1 || b[1] == 0xF9)) return 'audio/aac';
    if (b[0] == 0xFF && (b[1] & 0xE0) == 0xE0) return 'audio/mpeg';
    return null;
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
