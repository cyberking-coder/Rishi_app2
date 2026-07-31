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

/// An attachment hanging off a lesson: a handout or a link. Not a
/// teaching format of its own, so it never counts toward lesson totals
/// or progress.
enum ResourceType { pdf, image, file, link }

ResourceType resourceTypeFromString(String? value) {
  switch (value) {
    case 'image':
      return ResourceType.image;
    case 'file':
      return ResourceType.file;
    case 'link':
      return ResourceType.link;
    default:
      return ResourceType.pdf;
  }
}

class LessonResource {
  final String id;
  final String title;
  final ResourceType type;
  final String url;

  const LessonResource({
    required this.id,
    required this.title,
    required this.type,
    required this.url,
  });

  factory LessonResource.fromMap(Map<String, dynamic> map) => LessonResource(
        id: map['id'] as String? ?? '',
        title: map['title'] as String? ?? 'Resource',
        type: resourceTypeFromString(map['resource_type'] as String?),
        url: map['url'] as String? ?? '',
      );
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

  /// Handouts and links attached to this lesson.
  final List<LessonResource> resources;

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
    this.resources = const [],
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
      resources: [
        for (final r in (map['lesson_resources'] as List? ?? []))
          LessonResource.fromMap(Map<String, dynamic>.from(r as Map)),
      ],
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
  final int priceAmount;
  final bool owned;

  const CourseSummaryRef({
    required this.id,
    required this.title,
    required this.isPremium,
    this.description,
    this.coverImageUrl,
    this.priceAmount = 0,
    this.owned = false,
  });

  bool get isFree => priceAmount == 0;
  bool get isLocked => !isFree && !owned;

  String get priceLabel {
    if (isFree) return 'Free';
    final rupees = priceAmount / 100;
    return rupees == rupees.roundToDouble()
        ? '₹${rupees.round()}'
        : '₹${rupees.toStringAsFixed(2)}';
  }

  factory CourseSummaryRef.fromMap(
    Map<String, dynamic> map, {
    bool owned = false,
  }) =>
      CourseSummaryRef(
        id: map['id'] as String? ?? '',
        title: map['title'] as String? ?? 'Untitled',
        description: map['description'] as String?,
        coverImageUrl: map['cover_image_url'] as String?,
        isPremium: map['is_premium'] as bool? ?? true,
        priceAmount: (map['price_amount'] as num?)?.toInt() ?? 0,
        owned: owned,
      );
}
