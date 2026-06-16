import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/entities/download_task.dart';
import '../domain/repositories/download_repository.dart';

/// The repository is constructed + restored once in main.dart (the proxy
/// server and manifest must be ready before any playback/UI), then
/// injected here via a ProviderScope override — same pattern as the audio
/// handler.
final downloadRepositoryProvider = Provider<DownloadRepository>((ref) {
  throw UnimplementedError(
    'downloadRepositoryProvider must be overridden in main.dart after restore()',
  );
});

/// Reactive list of all downloads, seeded with the current snapshot so the
/// UI never flickers empty on first build.
final downloadTasksProvider = StreamProvider<List<DownloadTask>>((ref) {
  final repo = ref.watch(downloadRepositoryProvider);
  return repo.watchTasks();
});

/// Convenience: the download task for a given content id, if any.
final downloadForContentProvider =
    Provider.family<DownloadTask?, String>((ref, contentId) {
  final tasks = ref.watch(downloadTasksProvider).valueOrNull ??
      ref.watch(downloadRepositoryProvider).tasks;
  for (final task in tasks) {
    if (task.contentId == contentId) return task;
  }
  return null;
});
