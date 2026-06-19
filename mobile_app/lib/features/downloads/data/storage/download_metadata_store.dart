import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

import '../../domain/entities/download_task.dart';

/// Persists the download manifest (task metadata + non-secret IVs) to a
/// JSON file in the app sandbox. Secret key material is NOT stored here —
/// see [SecureDownloadStorage]. Writes are atomic (temp + rename) so an
/// interrupted write can't corrupt the manifest.
class DownloadMetadataStore {
  File? _file;

  Future<File> _manifest() async {
    if (_file != null) return _file!;
    final support = await getApplicationSupportDirectory();
    _file = File('${support.path}/offline/manifest.json');
    // Ensure the directory exists before any read or write attempt.
    await _file!.parent.create(recursive: true);
    return _file!;
  }

  Future<({List<DownloadTask> tasks, Map<String, Uint8List> ivs})> load() async {
    final file = await _manifest();
    if (!await file.exists()) {
      return (tasks: <DownloadTask>[], ivs: <String, Uint8List>{});
    }

    try {
      final json = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      final tasks = (json['tasks'] as List<dynamic>)
          .map((e) => DownloadTask.fromJson(e as Map<String, dynamic>))
          .toList();
      final ivs = (json['ivs'] as Map<String, dynamic>).map(
        (k, v) => MapEntry(k, base64Decode(v as String)),
      );
      return (tasks: tasks, ivs: ivs);
    } catch (_) {
      // Corrupt manifest — start clean rather than crash the app.
      return (tasks: <DownloadTask>[], ivs: <String, Uint8List>{});
    }
  }

  Future<void> save(
    List<DownloadTask> tasks,
    Map<String, Uint8List> ivs,
  ) async {
    final file = await _manifest();
    final payload = jsonEncode({
      'tasks': tasks.map((t) => t.toJson()).toList(),
      'ivs': ivs.map((k, v) => MapEntry(k, base64Encode(v))),
    });

    final tmp = File('${file.path}.tmp');
    await tmp.writeAsString(payload, flush: true);
    await tmp.rename(file.path);
  }
}
