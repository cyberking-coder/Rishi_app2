enum LessonType { audio, video, text }

LessonType lessonTypeFromString(String? value) {
  switch (value) {
    case 'video':
      return LessonType.video;
    case 'text':
      return LessonType.text;
    default:
      return LessonType.audio;
  }
}

class Lesson {
  final String id;
  final String title;
  final String? description;
  final LessonType type;
  final String? bodyMarkdown;
  final bool completed;

  /// Audio lessons reference an `audios` row. These are the fields the
  /// existing playback pipeline needs to build an AudioTrack — note the
  /// id here is the AUDIO's id, not the lesson's, because that's what
  /// issue-audio-license is keyed on.
  final String? audioId;
  final String? audioTitle;
  final String? audioArtist;
  final String? audioCoverArtUrl;
  final int? audioDurationSeconds;

  final String? videoId;
  final String? videoTitle;

  const Lesson({
    required this.id,
    required this.title,
    required this.type,
    this.description,
    this.bodyMarkdown,
    this.completed = false,
    this.audioId,
    this.audioTitle,
    this.audioArtist,
    this.audioCoverArtUrl,
    this.audioDurationSeconds,
    this.videoId,
    this.videoTitle,
  });

  /// True when the lesson claims a media type but the row it pointed at is
  /// gone (media is ON DELETE SET NULL, so this is a legitimate state).
  bool get isPlayable {
    switch (type) {
      case LessonType.audio:
        return audioId != null;
      case LessonType.video:
        return videoId != null;
      case LessonType.text:
        return bodyMarkdown != null;
    }
  }

  factory Lesson.fromMap(Map<String, dynamic> map, {bool completed = false}) {
    final audio = map['audios'] as Map<String, dynamic>?;
    final video = map['videos'] as Map<String, dynamic>?;
    return Lesson(
      id: map['id'] as String? ?? '',
      title: map['title'] as String? ?? 'Untitled',
      description: map['description'] as String?,
      type: lessonTypeFromString(map['lesson_type'] as String?),
      bodyMarkdown: map['body_markdown'] as String?,
      completed: completed,
      audioId: audio?['id'] as String?,
      audioTitle: audio?['title'] as String?,
      audioArtist: audio?['artist'] as String?,
      audioCoverArtUrl: audio?['cover_art_url'] as String?,
      audioDurationSeconds: audio?['duration_seconds'] as int?,
      videoId: video?['id'] as String?,
      videoTitle: video?['title'] as String?,
    );
  }
}

class CourseModule {
  final String id;
  final String title;
  final List<Lesson> lessons;

  const CourseModule({
    required this.id,
    required this.title,
    required this.lessons,
  });
}

class CourseDetail {
  final CourseSummaryRef course;
  final List<CourseModule> modules;

  const CourseDetail({required this.course, required this.modules});

  List<Lesson> get allLessons => [for (final m in modules) ...m.lessons];
  int get lessonCount => allLessons.length;
  int get completedCount => allLessons.where((l) => l.completed).length;
  double get progressFraction =>
      lessonCount == 0 ? 0 : completedCount / lessonCount;

  /// The next unfinished lesson, for the "continue" affordance.
  Lesson? get nextLesson {
    for (final lesson in allLessons) {
      if (!lesson.completed && lesson.isPlayable) return lesson;
    }
    return null;
  }
}

/// Minimal course fields needed by the detail screen (kept separate from
/// CourseSummary, which carries catalog-only progress counts).
class CourseSummaryRef {
  final String id;
  final String title;
  final String? description;
  final String? coverImageUrl;
  final bool isPremium;

  const CourseSummaryRef({
    required this.id,
    required this.title,
    required this.isPremium,
    this.description,
    this.coverImageUrl,
  });

  factory CourseSummaryRef.fromMap(Map<String, dynamic> map) =>
      CourseSummaryRef(
        id: map['id'] as String? ?? '',
        title: map['title'] as String? ?? 'Untitled',
        description: map['description'] as String?,
        coverImageUrl: map['cover_image_url'] as String?,
        isPremium: map['is_premium'] as bool? ?? true,
      );
}
