import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../../domain/entities/download_task.dart';

/// How a manifest read ended.
///
/// The distinction that matters is [absent] versus [corrupt]. Both yield
/// an empty list, but only one of them is normal — and conflating them is
/// what let a parse failure look exactly like a new install.
enum ManifestOutcome {
  /// No manifest on disk. Expected for anyone who has never downloaded.
  absent,

  /// Read and parsed. [ManifestLoad.tasks] is authoritative, empty or not.
  loaded,

  /// Present but unreadable. The old contents are NOT known, so nothing
  /// may be written over them until the user acts.
  corrupt,
}

@immutable
class ManifestLoad {
  final ManifestOutcome outcome;
  final List<DownloadTask> tasks;
  final Map<String, Uint8List> ivs;

  const ManifestLoad({
    required this.outcome,
    required this.tasks,
    required this.ivs,
  });

  /// True when the on-disk state is known — the only condition under
  /// which overwriting it is safe.
  bool get isAuthoritative =>
      outcome == ManifestOutcome.absent || outcome == ManifestOutcome.loaded;
}

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

  Future<ManifestLoad> load() async {
    final file = await _manifest();
    if (!await file.exists()) {
      return const ManifestLoad(
        outcome: ManifestOutcome.absent,
        tasks: [],
        ivs: {},
      );
    }

    try {
      final json = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      final tasks = (json['tasks'] as List<dynamic>)
          .map((e) => DownloadTask.fromJson(e as Map<String, dynamic>))
          .toList();
      final ivs = (json['ivs'] as Map<String, dynamic>).map(
        (k, v) => MapEntry(k, base64Decode(v as String)),
      );
      return ManifestLoad(
        outcome: ManifestOutcome.loaded,
        tasks: tasks,
        ivs: ivs,
      );
    } catch (e, st) {
      // This used to be `catch (_)` returning an empty list, on the
      // reasoning that starting clean beats crashing. Starting clean is
      // still right — but discarding the exception meant a manifest that
      // failed to parse was indistinguishable from a user who had never
      // downloaded anything, on screen AND in the logs. A whole class of
      // "my downloads vanished" report had nowhere to be diagnosed from.
      //
      // The failure is now named, and the file that caused it is kept.
      debugPrint('DownloadMetadataStore.load: manifest unreadable: $e\n$st');
      await _quarantine(file);
      return const ManifestLoad(
        outcome: ManifestOutcome.corrupt,
        tasks: [],
        ivs: {},
      );
    }
  }

  /// Moves an unreadable manifest aside instead of leaving it to be
  /// overwritten. It is the only evidence of what went wrong, it is a few
  /// kilobytes, and a single fixed name means these cannot accumulate.
  Future<void> _quarantine(File file) async {
    try {
      await file.rename('${file.path}.corrupt');
    } catch (e) {
      debugPrint('DownloadMetadataStore: could not quarantine manifest: $e');
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
