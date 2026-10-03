import 'package:flutter_test/flutter_test.dart';
import 'package:meditation_app/features/lms/domain/entities/lesson.dart';

/// Parsing + access/progress logic for courses and lessons. Covers the
/// "malformed row must not crash" class (missing fields, dangling media)
/// and the paid/free/owned gating that decides what a user can open.
void main() {
  group('enum parsing', () {
    test('lessonTypeFromString maps known values and defaults to audio', () {
      expect(lessonTypeFromString('video'), LessonType.video);
      expect(lessonTypeFromString('text'), LessonType.text);
      expect(lessonTypeFromString('audio'), LessonType.audio);
      expect(lessonTypeFromString(null), LessonType.audio);
      expect(lessonTypeFromString('nonsense'), LessonType.audio);
    });

    test('resourceTypeFromString maps known values and defaults to pdf', () {
      expect(resourceTypeFromString('image'), ResourceType.image);
      expect(resourceTypeFromString('file'), ResourceType.file);
      expect(resourceTypeFromString('link'), ResourceType.link);
      expect(resourceTypeFromString(null), ResourceType.pdf);
    });
  });

  group('Lesson.fromMap', () {
    test('parses an audio lesson with its embedded audio row', () {
      final l = Lesson.fromMap({
        'id': 'l1',
        'title': 'Breath',
        'lesson_type': 'audio',
        'audios': {
          'id': 'aud1',
          'title': 'Breath Audio',
          'artist': 'AR',
          'cover_art_url': 'u',
          'duration_seconds': 300,
        },
      });
      expect(l.type, LessonType.audio);
      expect(l.audioId, 'aud1');
      expect(l.isPlayable, isTrue);
    });

    test('an audio lesson whose media row is gone is not playable, not a crash',
        () {
      final l = Lesson.fromMap({
        'id': 'l2',
        'title': 'Orphaned',
        'lesson_type': 'audio',
        'audios': null,
      });
      expect(l.audioId, isNull);
      expect(l.isPlayable, isFalse);
    });

    test('tolerates a nearly-empty row without throwing', () {
      final l = Lesson.fromMap({});
      expect(l.id, '');
      expect(l.title, 'Untitled');
      expect(l.type, LessonType.audio);
      expect(l.isPlayable, isFalse);
      expect(l.resources, isEmpty);
    });

    test('parses lesson resources', () {
      final l = Lesson.fromMap({
        'id': 'l3',
        'title': 'With handout',
        'lesson_type': 'text',
        'body_markdown': '# hi',
        'lesson_resources': [
          {'id': 'r1', 'title': 'PDF', 'resource_type': 'pdf', 'url': 'u'},
          {'id': 'r2', 'title': 'Link', 'resource_type': 'link', 'url': 'u2'},
        ],
      });
      expect(l.resources.length, 2);
      expect(l.resources.first.type, ResourceType.pdf);
      expect(l.resources.last.type, ResourceType.link);
      expect(l.isPlayable, isTrue); // text with body
    });
  });

  group('CourseSummaryRef pricing + gating', () {
    CourseSummaryRef ref({int price = 0, bool owned = false}) =>
        CourseSummaryRef.fromMap(
          {'id': 'c1', 'title': 'Awaken', 'price_amount': price},
          owned: owned,
        );

    test('free course is free and never locked', () {
      final c = ref(price: 0);
      expect(c.isFree, isTrue);
      expect(c.priceLabel, 'Free');
      expect(c.isLocked, isFalse);
    });

    test('paid course is locked until owned', () {
      expect(ref(price: 49900, owned: false).isLocked, isTrue);
      expect(ref(price: 49900, owned: true).isLocked, isFalse);
    });

    test('price label renders whole and fractional rupees', () {
      expect(ref(price: 50000).priceLabel, '₹500');
      expect(ref(price: 49950).priceLabel, '₹499.50');
    });
  });

  group('CourseDetail progress', () {
    Lesson lesson(String id, {bool completed = false, bool playable = true}) =>
        Lesson(
          id: id,
          title: id,
          type: LessonType.audio,
          audioId: playable ? 'aud_$id' : null,
          completed: completed,
        );

    test('progressFraction and completedCount reflect completed lessons', () {
      final detail = CourseDetail(
        course: const CourseSummaryRef(id: 'c', title: 'c', isPremium: false),
        modules: [
          CourseModule(id: 'm', title: 'm', lessons: [
            lesson('a', completed: true),
            lesson('b'),
            lesson('c', completed: true),
            lesson('d'),
          ]),
        ],
      );
      expect(detail.lessonCount, 4);
      expect(detail.completedCount, 2);
      expect(detail.progressFraction, 0.5);
    });

    test('empty course has zero progress, not a divide-by-zero', () {
      const detail = CourseDetail(
        course: CourseSummaryRef(id: 'c', title: 'c', isPremium: false),
        modules: [],
      );
      expect(detail.lessonCount, 0);
      expect(detail.progressFraction, 0);
      expect(detail.nextLesson, isNull);
    });

    test('nextLesson is the first incomplete, playable lesson', () {
      final detail = CourseDetail(
        course: const CourseSummaryRef(id: 'c', title: 'c', isPremium: false),
        modules: [
          CourseModule(id: 'm', title: 'm', lessons: [
            lesson('a', completed: true),
            lesson('b', completed: false, playable: false), // skipped: dangling
            lesson('c', completed: false),
          ]),
        ],
      );
      expect(detail.nextLesson?.id, 'c');
    });
  });
}
