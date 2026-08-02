import 'package:supabase_flutter/supabase_flutter.dart';

/// Reads courses/modules/lessons and the caller's lesson progress.
///
/// RLS already restricts courses to published-or-admin, and modules and
/// lessons inherit that through their parent-course policies, so these
/// queries don't filter on status themselves.
class LmsRemoteDataSource {
  final SupabaseClient _client;

  LmsRemoteDataSource(this._client);

  Future<List<Map<String, dynamic>>> getCourses() async {
    final rows = await _client
        .from('courses')
        .select(
          'id, title, description, cover_image_url, is_premium, price_amount, '
          'sort_order, course_modules(id, lessons(id))',
        )
        .order('sort_order', ascending: true)
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(rows as List);
  }

  Future<Map<String, dynamic>?> getCourse(String courseId) async {
    return await _client
        .from('courses')
        .select(
          'id, title, description, cover_image_url, is_premium, price_amount',
        )
        .eq('id', courseId)
        .maybeSingle();
  }

  Future<List<Map<String, dynamic>>> getModules(String courseId) async {
    final rows = await _client
        .from('course_modules')
        .select(
          'id, title, position, '
          'lessons(id, title, description, lesson_type, body_markdown, '
          'position, lesson_resources(id, title, resource_type, url, position), '
          'audios(id, title, artist, cover_art_url, duration_seconds), '
          'videos(id, title))',
        )
        .eq('course_id', courseId)
        .order('position', ascending: true);
    return List<Map<String, dynamic>>.from(rows as List);
  }

  /// Course ids this user currently has access to by purchase. RLS
  /// scopes course_purchases to their own rows, so no explicit user
  /// filter is needed.
  ///
  /// An admin can withdraw access to a single course, which dates
  /// `expires_at` in the past rather than deleting the sale. Filtering on
  /// status alone therefore left the course looking unlocked in the app
  /// long after has_course_access() had stopped agreeing — the lock UI
  /// said open, and playback then refused.
  Future<Set<String>> getPurchasedCourseIds() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return {};

    final rows = await _client
        .from('course_purchases')
        .select('course_id')
        .eq('status', 'paid')
        .or('expires_at.is.null,expires_at.gt.${DateTime.now().toUtc().toIso8601String()}');

    return {
      for (final row in rows as List) (row as Map)['course_id'] as String,
    };
  }

  /// Lesson ids the caller has completed. RLS scopes this to their own
  /// rows, so no explicit user filter is needed.
  Future<Set<String>> getCompletedLessonIds() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return {};

    final rows = await _client
        .from('lesson_progress')
        .select('lesson_id')
        .eq('completed', true);

    return {
      for (final row in rows as List) (row as Map)['lesson_id'] as String,
    };
  }

  /// lesson_progress has a plain unique (user_id, lesson_id), so unlike
  /// watch_history this needs no RPC — a normal upsert can target it.
  Future<void> markLessonCompleted(String lessonId) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;

    await _client.from('lesson_progress').upsert(
      {
        'user_id': userId,
        'lesson_id': lessonId,
        'completed': true,
        'last_accessed_at': DateTime.now().toUtc().toIso8601String(),
      },
      onConflict: 'user_id,lesson_id',
    );
  }
}
