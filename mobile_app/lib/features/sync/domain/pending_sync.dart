/// One piece of listen/watch progress captured while offline, to be replayed
/// to the server when connectivity returns.
class WatchProgressEvent {
  final String audioId;
  final int progressSeconds;
  final int durationSeconds;
  final bool completed;

  const WatchProgressEvent({
    required this.audioId,
    required this.progressSeconds,
    required this.durationSeconds,
    required this.completed,
  });

  Map<String, dynamic> toJson() => {
        'audioId': audioId,
        'progressSeconds': progressSeconds,
        'durationSeconds': durationSeconds,
        'completed': completed,
      };

  static WatchProgressEvent? fromJson(Map<String, dynamic> j) {
    final id = j['audioId'] as String?;
    if (id == null) return null;
    return WatchProgressEvent(
      audioId: id,
      progressSeconds: (j['progressSeconds'] as num?)?.toInt() ?? 0,
      durationSeconds: (j['durationSeconds'] as num?)?.toInt() ?? 0,
      completed: j['completed'] as bool? ?? false,
    );
  }
}

/// The local, durable queue of actions taken offline that the server has not
/// seen yet. Immutable + pure, so the merge/dedupe rules are unit-testable;
/// the file store wraps it.
///
/// Watch progress is keyed by audio id — only the LATEST position per track
/// matters, so a new entry overwrites the old and the queue can't grow without
/// bound during a long offline session. Lesson completions are a set (idempotent).
class PendingSync {
  final Map<String, WatchProgressEvent> watch;
  final Set<String> completedLessons;

  const PendingSync({this.watch = const {}, this.completedLessons = const {}});

  bool get isEmpty => watch.isEmpty && completedLessons.isEmpty;

  PendingSync withWatch(WatchProgressEvent e) => PendingSync(
        watch: {...watch, e.audioId: e},
        completedLessons: completedLessons,
      );

  PendingSync withLessonCompleted(String lessonId) => PendingSync(
        watch: watch,
        completedLessons: {...completedLessons, lessonId},
      );

  PendingSync withoutWatch(String audioId) => PendingSync(
        watch: {...watch}..remove(audioId),
        completedLessons: completedLessons,
      );

  PendingSync withoutLesson(String lessonId) => PendingSync(
        watch: watch,
        completedLessons: {...completedLessons}..remove(lessonId),
      );

  Map<String, dynamic> toJson() => {
        'watch': {for (final e in watch.entries) e.key: e.value.toJson()},
        'lessons': completedLessons.toList(),
      };

  static PendingSync fromJson(Map<String, dynamic> j) {
    final watch = <String, WatchProgressEvent>{};
    final rawWatch = j['watch'];
    if (rawWatch is Map) {
      rawWatch.forEach((key, value) {
        if (value is Map) {
          final e = WatchProgressEvent.fromJson(Map<String, dynamic>.from(value));
          if (e != null) watch[key as String] = e;
        }
      });
    }
    final rawLessons = j['lessons'];
    final lessons = <String>{
      if (rawLessons is List)
        for (final l in rawLessons)
          if (l is String) l,
    };
    return PendingSync(watch: watch, completedLessons: lessons);
  }
}
