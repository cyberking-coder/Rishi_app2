import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../domain/entities/download_content_type.dart';
import '../../domain/entities/download_status.dart';
import '../../domain/entities/download_task.dart';
import '../../domain/repositories/download_repository.dart';
import '../crypto/file_crypto.dart';
import '../net/local_decrypting_proxy.dart';
import '../sources/download_source_resolver.dart';
import '../storage/download_metadata_store.dart';
import '../storage/secure_download_storage.dart';

/// Per-download cooperative control flags, checked inside the streaming
/// loop so pause/cancel take effect promptly without killing the isolate.
class _DownloadControl {
  bool pauseRequested = false;
  bool cancelRequested = false;
}

/// The download engine. Streams bytes over HTTP with Range support,
/// encrypts each chunk with AES-CTR before it ever hits disk, persists
/// progress, and exposes everything as a reactive task list.
class DownloadRepositoryImpl implements DownloadRepository {
  DownloadRepositoryImpl({
    required SecureDownloadStorage storage,
    required DownloadMetadataStore metadataStore,
    required DownloadSourceResolver resolver,
    required LocalDecryptingProxy proxy,
    http.Client? httpClient,
  })  : _storage = storage,
        _metadata = metadataStore,
        _resolver = resolver,
        _proxy = proxy,
        _httpClient = httpClient ?? http.Client();

  final SecureDownloadStorage _storage;
  final DownloadMetadataStore _metadata;
  final DownloadSourceResolver _resolver;
  final LocalDecryptingProxy _proxy;
  final http.Client _httpClient;

  final Map<String, DownloadTask> _tasks = {};
  final Map<String, Uint8List> _ivs = {};
  final Map<String, _DownloadControl> _controls = {};

  final _controller = StreamController<List<DownloadTask>>.broadcast();

  // Emit/persist throttling thresholds.
  static const _emitEveryBytes = 256 * 1024;
  static const _persistEveryBytes = 2 * 1024 * 1024;

  @override
  Stream<List<DownloadTask>> watchTasks() async* {
    // Seed new subscribers with the current snapshot — the broadcast
    // controller does NOT replay its last value, and restore() emits once
    // at startup before this screen ever subscribes. Without this initial
    // yield the StreamProvider stays in `loading` forever (blank spinner).
    yield _sortedTasks();
    yield* _controller.stream;
  }

  @override
  List<DownloadTask> get tasks => _sortedTasks();

  /// Whether the on-disk manifest has been read successfully.
  ///
  /// Until it has, this object does not know what the user owns, and
  /// [_persist] must not write. See the comment there — this flag is the
  /// whole defence against a failed startup silently destroying somebody's
  /// downloads.
  bool _manifestKnown = false;

  @override
  Future<void> restore() async {
    // ── Order matters, and it used to be the other way round ──────────
    // `await _proxy.start()` came first. If binding the loopback socket
    // threw, restore() aborted before ever reading the manifest, main.dart
    // caught the exception and only debugPrint'd it, and the app came up
    // showing an empty Downloads screen while every file and the manifest
    // itself sat intact on disk. Reading the manifest is the part that
    // must not be prevented by anything else, so it goes first and the
    // network comes second.
    final loaded = await _metadata.load();
    _manifestKnown = loaded.isAuthoritative;

    for (final task in loaded.tasks) {
      // Anything left mid-flight when the app died is resumable.
      final reconciled = task.status == DownloadStatus.downloading ||
              task.status == DownloadStatus.queued
          ? task.copyWith(status: DownloadStatus.paused)
          : task;
      _tasks[task.id] = reconciled;
    }
    _ivs.addAll(loaded.ivs);
    _emit();

    if (!_manifestKnown) {
      debugPrint(
        'DownloadRepository: manifest unreadable — the download list will '
        'show empty and will NOT be overwritten. The previous manifest is '
        'kept at manifest.json.corrupt.',
      );
    }

    // Second, and allowed to fail. The proxy only matters at playback,
    // and register() starts it on demand, so a failure here costs nothing
    // at launch and is retried the moment somebody presses play.
    try {
      await _proxy.start();
    } catch (e, st) {
      debugPrint('DownloadRepository: local playback proxy failed to '
          'start, will retry on playback: $e\n$st');
    }
  }

  @override
  Future<String> enqueue({
    required String contentId,
    required DownloadContentType contentType,
    required String title,
    String? thumbnailUrl,
  }) async {
    // Reuse an existing entry for the same content (re-download / retry).
    final existing = _tasks.values
        .where((t) => t.contentId == contentId)
        .cast<DownloadTask?>()
        .firstWhere((_) => true, orElse: () => null);
    if (existing != null) {
      if (existing.status.isResumable) {
        await resume(existing.id);
        return existing.id;
      }
      return existing.id;
    }

    final id = '${contentType.wireName}_${contentId}_'
        '${DateTime.now().millisecondsSinceEpoch}';

    final cipherKey = await _storage.createKey(id);
    _ivs[id] = cipherKey.iv;

    _tasks[id] = DownloadTask(
      id: id,
      contentId: contentId,
      contentType: contentType,
      title: title,
      thumbnailUrl: thumbnailUrl,
      status: DownloadStatus.queued,
      receivedBytes: 0,
      createdAt: DateTime.now(),
    );
    await _persist();
    _emit();

    unawaited(_run(id, cipherKey));
    return id;
  }

  @override
  Future<void> pause(String downloadId) async {
    final ctrl = _controls[downloadId];
    if (ctrl != null) ctrl.pauseRequested = true;
    // If it wasn't actively running, flip the state directly.
    final task = _tasks[downloadId];
    if (task != null && !task.status.isActive) {
      _tasks[downloadId] = task.copyWith(status: DownloadStatus.paused);
      await _persist();
      _emit();
    }
  }

  @override
  Future<void> resume(String downloadId) async {
    final task = _tasks[downloadId];
    if (task == null || task.status.isActive) return;

    final cipherKey = await _storage.loadKey(downloadId, _ivs[downloadId]!);
    if (cipherKey == null) {
      _fail(downloadId, 'Encryption key missing — please re-download.');
      return;
    }
    unawaited(_run(downloadId, cipherKey));
  }

  @override
  Future<void> delete(String downloadId) async {
    final ctrl = _controls[downloadId];
    if (ctrl != null) ctrl.cancelRequested = true;

    _proxy.unregister(downloadId);
    await _storage.purge(downloadId);
    _tasks.remove(downloadId);
    _ivs.remove(downloadId);
    await _persist();
    _emit();
  }

  @override
  bool isDownloaded(String contentId) => _tasks.values.any(
        (t) => t.contentId == contentId && t.status.isPlayable,
      );

  @override
  Future<Uri> localPlaybackUrl(String contentId) async {
    final task = _tasks.values.firstWhere(
      (t) => t.contentId == contentId && t.status.isPlayable,
      orElse: () => throw StateError('Not available offline'),
    );

    final cipherKey = await _storage.loadKey(task.id, _ivs[task.id]!);
    if (cipherKey == null) {
      throw StateError('Encryption key missing for offline file');
    }
    final file = await _storage.encryptedFile(task.id);
    // register() starts the proxy if it isn't running, so an offline file
    // stays playable even when the bind failed at launch.
    return await _proxy.register(
      task.id,
      file,
      cipherKey,
      task.contentType.mimeType,
    );
  }

  @override
  Future<void> purgeRevokedAndExpired() async {
    // Locally-detectable expiry first.
    final expired = _tasks.values.where((t) => t.isLicenseExpired).toList();
    for (final t in expired) {
      await delete(t.id);
    }

    // Then server-side revocations.
    try {
      final revoked = await _resolver.revokedContentIds();
      final toPurge = _tasks.values
          .where((t) => revoked.contains(t.contentId))
          .map((t) => t.id)
          .toList();
      for (final id in toPurge) {
        await delete(id);
      }
    } catch (_) {
      // Offline / transient — try again next launch.
    }
  }

  @override
  Future<void> purgeAll() async {
    // Not a loop over delete(). That rewrites the entire manifest and
    // pushes a new list to every listener once per download, so clearing
    // n items cost n full JSON serialisations and n widget rebuilds —
    // enough to visibly stall the frame on the screen that triggers it.
    // The state is dropped in memory first, then written once.
    final ids = _tasks.values.map((t) => t.id).toList();
    if (ids.isEmpty) return;

    for (final id in ids) {
      _controls[id]?.cancelRequested = true;
      _proxy.unregister(id);
      _tasks.remove(id);
      _ivs.remove(id);
    }
    await _persist();
    _emit();

    // Files last, and off the path the UI is waiting on. The manifest is
    // already empty, so an app killed midway through this cannot come
    // back showing downloads whose bytes are gone.
    for (final id in ids) {
      await _storage.purge(id);
    }
  }

  // --- core engine ---------------------------------------------------------

  Future<void> _run(String id, DownloadCipherKey cipherKey) async {
    final control = _DownloadControl();
    _controls[id] = control;

    var task = _tasks[id]!.copyWith(
      status: DownloadStatus.downloading,
      clearError: true,
    );
    _tasks[id] = task;
    _emit();

    try {
      final url = await _resolver.resolve(task.contentId, task.contentType);
      var received = task.receivedBytes;

      final request = http.Request('GET', url);
      if (received > 0) request.headers['range'] = 'bytes=$received-';
      final response = await _httpClient.send(request);

      // Server ignored our Range request → restart cleanly from zero.
      if (received > 0 && response.statusCode == 200) {
        received = 0;
      }
      if (response.statusCode != 200 && response.statusCode != 206) {
        throw http.ClientException('Unexpected status ${response.statusCode}');
      }

      final total = _resolveTotal(response, received);
      task = task.copyWith(totalBytes: total, receivedBytes: received);
      _tasks[id] = task;

      final file = await _storage.encryptedFile(id);
      final raf = await file.open(
        mode: received > 0 ? FileMode.append : FileMode.write,
      );
      if (received > 0) await raf.truncate(received);

      final transformer = CtrTransformer.atOffset(cipherKey, received);
      var lastEmit = received;
      var lastPersist = received;

      try {
        await for (final chunk in response.stream) {
          if (control.cancelRequested) {
            await raf.close();
            return; // delete() handles cleanup.
          }
          if (control.pauseRequested) break;

          final encrypted = transformer.process(Uint8List.fromList(chunk));
          await raf.writeFrom(encrypted);
          received += chunk.length;

          task = task.copyWith(receivedBytes: received);
          _tasks[id] = task;

          if (received - lastEmit >= _emitEveryBytes) {
            lastEmit = received;
            _emit();
          }
          if (received - lastPersist >= _persistEveryBytes) {
            lastPersist = received;
            await _persist();
          }
        }
      } finally {
        await raf.close();
      }

      if (control.pauseRequested) {
        task = task.copyWith(status: DownloadStatus.paused);
        _tasks[id] = task;
        await _persist();
        _emit();
        return;
      }

      // Stream ended on its own → finished.
      task = task.copyWith(
        status: DownloadStatus.completed,
        totalBytes: task.totalBytes ?? received,
        receivedBytes: received,
      );
      _tasks[id] = task;
      await _persist();
      _emit();

      unawaited(_resolver.recordServerDownload(
        contentId: task.contentId,
        type: task.contentType,
      ));
    } catch (e) {
      _fail(id, e.toString());
    } finally {
      _controls.remove(id);
    }
  }

  int? _resolveTotal(http.StreamedResponse response, int received) {
    final contentRange = response.headers['content-range'];
    if (contentRange != null && contentRange.contains('/')) {
      final totalStr = contentRange.split('/').last.trim();
      final total = int.tryParse(totalStr);
      if (total != null) return total;
    }
    final len = response.contentLength;
    if (len != null) return received + len;
    return null;
  }

  void _fail(String id, String message) {
    final task = _tasks[id];
    if (task == null) return;
    _tasks[id] = task.copyWith(
      status: DownloadStatus.failed,
      errorMessage: message,
    );
    unawaited(_persist());
    _emit();
  }

  List<DownloadTask> _sortedTasks() {
    final list = _tasks.values.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  void _emit() {
    if (!_controller.isClosed) _controller.add(_sortedTasks());
  }

  /// Writes the manifest — but only when we know what we are replacing.
  ///
  /// This guard exists because the failure it prevents is silent and
  /// irreversible. If restore() could not read the manifest, `_tasks` is
  /// empty while the real manifest is still on disk. The very next
  /// enqueue() would serialise that empty-plus-one state over the top,
  /// destroying every previous entry and orphaning its .enc file on disk
  /// forever — bytes nothing references and no screen can reach.
  ///
  /// So a startup failure costs the user a temporarily empty list, which
  /// the next successful launch restores, instead of costing them their
  /// library permanently one download later.
  Future<void> _persist() async {
    if (!_manifestKnown) {
      debugPrint(
        'DownloadRepository: refusing to write the manifest — it was never '
        'read successfully this session, and writing would destroy it.',
      );
      return;
    }
    await _metadata.save(_sortedTasks(), _ivs);
  }

  @override
  Future<void> dispose() async {
    for (final ctrl in _controls.values) {
      ctrl.cancelRequested = true;
    }
    _httpClient.close();
    await _proxy.dispose();
    await _controller.close();
  }
}
