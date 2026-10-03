import 'package:flutter_test/flutter_test.dart';
import 'package:meditation_app/features/sync/domain/pending_sync.dart';

/// The offline queue's merge/dedupe rules — what keeps an offline session's
/// progress from being lost and the queue from growing without bound.
void main() {
  WatchProgressEvent watch(String id, int secs) => WatchProgressEvent(
        audioId: id,
        progressSeconds: secs,
        durationSeconds: 600,
        completed: false,
      );

  test('empty by default', () {
    expect(const PendingSync().isEmpty, isTrue);
  });

  test('watch progress is keyed by audio id — latest wins (no unbounded growth)',
      () {
    final p = const PendingSync()
        .withWatch(watch('a', 10))
        .withWatch(watch('a', 42)) // same track, newer position
        .withWatch(watch('b', 5));
    expect(p.watch.length, 2);
    expect(p.watch['a']!.progressSeconds, 42);
    expect(p.watch['b']!.progressSeconds, 5);
  });

  test('completed lessons are an idempotent set', () {
    final p = const PendingSync()
        .withLessonCompleted('l1')
        .withLessonCompleted('l1')
        .withLessonCompleted('l2');
    expect(p.completedLessons, {'l1', 'l2'});
  });

  test('removal clears a synced item', () {
    final p = const PendingSync()
        .withWatch(watch('a', 10))
        .withLessonCompleted('l1');
    final afterWatch = p.withoutWatch('a');
    expect(afterWatch.watch, isEmpty);
    expect(afterWatch.completedLessons, {'l1'});
    final afterLesson = afterWatch.withoutLesson('l1');
    expect(afterLesson.isEmpty, isTrue);
  });

  test('json round-trips both queues', () {
    final p = const PendingSync()
        .withWatch(watch('a', 120))
        .withLessonCompleted('l1');
    final back = PendingSync.fromJson(p.toJson());
    expect(back.watch['a']!.progressSeconds, 120);
    expect(back.watch['a']!.durationSeconds, 600);
    expect(back.completedLessons, {'l1'});
  });

  test('malformed json degrades to empty, not a crash', () {
    expect(PendingSync.fromJson(const {}).isEmpty, isTrue);
    expect(PendingSync.fromJson(const {'watch': 'nonsense', 'lessons': 7}).isEmpty,
        isTrue);
  });
}
