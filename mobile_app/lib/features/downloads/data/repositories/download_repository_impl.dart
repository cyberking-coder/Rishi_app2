import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

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
  Stream<List<DownloadTask>> watchTasks() => _controller.stream;

  @override
  List<DownloadTask> get tasks => _sortedTasks();

  @override
  Future<void> restore() async {
    await _proxy.start();
    final loaded = await _metadata.load();
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
    return _proxy.register(
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
    _persist();
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

  Future<void> _persist() => _metadata.save(_sortedTasks(), _ivs);

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
