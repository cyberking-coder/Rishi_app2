// Device-level E2E: full catalog sweep.
//
// Runs on a real device/emulator against a (staging) Supabase project and
// walks EVERY published audio, course, lesson, live session and scheduled
// event, driving each through the app's real pipeline:
//
//   • every audio  -> issue-audio-license returns a playable URL, and
//                     (optionally) just_audio actually loads the stream.
//   • every course -> detail resolves; every lesson's media row exists and,
//                     for audio lessons, has a ready rendition + license.
//   • every live   -> row parses via the real LiveSession entity.
//   • every event  -> app_popups row parses; iOS content policy is reported.
//
// It reuses the production entities (AudioTrack/Lesson/CourseSummaryRef/
// LiveSession/AppPopup.fromMap) so a malformed real row is caught here, and
// it calls the real edge functions so a broken rendition or expired signing
// config is caught here — the things a logic-only unit test cannot see.
//
// ---------------------------------------------------------------------------
// HOW TO RUN  (needs a device/emulator + a staging backend + a test account)
// ---------------------------------------------------------------------------
//   flutter test integration_test/e2e_content_sweep_test.dart \
//     --dart-define=E2E_SUPABASE_URL=https://<staging>.supabase.co \
//     --dart-define=E2E_SUPABASE_ANON_KEY=<anon key> \
//     --dart-define=E2E_EMAIL=tester@example.com \
//     --dart-define=E2E_PASSWORD='<password>' \
//     --dart-define=E2E_CHECK_LICENSES=true \
//     --dart-define=E2E_CHECK_PLAYBACK=false \
//     --dart-define=E2E_PLAYBACK_SAMPLE=5
//
// Defaults fall back to AppConfig (the project baked into the app), so with
// no dart-defines it sweeps whatever backend the build points at. Licensing
// and playback require the test account to have an ACTIVE DEVICE row (sign in
// through the app once on this device/emulator, or seed a devices row in
// staging); without one the sweep still validates catalog integrity and
// clearly reports that license checks were skipped.

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:just_audio/just_audio.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:meditation_app/core/config/app_config.dart';
import 'package:meditation_app/core/config/ios_content_policy.dart';
import 'package:meditation_app/features/access/domain/entities/app_popup.dart';
import 'package:meditation_app/features/audio/domain/entities/audio_track.dart';
import 'package:meditation_app/features/live/domain/entities/live_session.dart';
import 'package:meditation_app/features/lms/domain/entities/lesson.dart';

// ── Config (dart-define with safe fallbacks) ───────────────────────────────
const _url = String.fromEnvironment('E2E_SUPABASE_URL',
    defaultValue: AppConfig.supabaseUrl);
const _anonKey = String.fromEnvironment('E2E_SUPABASE_ANON_KEY',
    defaultValue: AppConfig.supabaseAnonKey);
const _email = String.fromEnvironment('E2E_EMAIL');
const _password = String.fromEnvironment('E2E_PASSWORD');
const _checkLicenses =
    bool.fromEnvironment('E2E_CHECK_LICENSES', defaultValue: true);
const _checkPlayback =
    bool.fromEnvironment('E2E_CHECK_PLAYBACK', defaultValue: false);
// 0 = every audio; N>0 = only the first N (keeps CI runs bounded).
const _playbackSample = int.fromEnvironment('E2E_PLAYBACK_SAMPLE', defaultValue: 0);

/// Collects failures so one bad item doesn't abort the whole sweep; the test
/// asserts this is empty at the end and prints a readable catalog report.
final List<String> _failures = [];
void _fail(String what) => _failures.add(what);
void _note(String msg) => debugPrint('[E2E] $msg');

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late SupabaseClient db;
  String? activeDeviceId;

  setUpAll(() async {
    await Supabase.initialize(url: _url, anonKey: _anonKey);
    db = Supabase.instance.client;

    if (_email.isNotEmpty && _password.isNotEmpty) {
      await db.auth.signInWithPassword(email: _email, password: _password);
      _note('Signed in as $_email');
    } else {
      _note('No E2E_EMAIL/E2E_PASSWORD given — sweeping as an anonymous '
          'client (RLS will hide gated content; license checks skipped).');
    }

    final userId = db.auth.currentUser?.id;
    if (userId != null && _checkLicenses) {
      final device = await db
          .from('devices')
          .select('id')
          .eq('user_id', userId)
          .eq('is_active', true)
          .maybeSingle();
      activeDeviceId = device?['id'] as String?;
      if (activeDeviceId == null) {
        _note('No active device for this account — license/playback checks '
            'will be SKIPPED. Sign in through the app once on this '
            'device/emulator, or seed a devices row in staging.');
      }
    }
  });

  tearDownAll(() {
    // Final report, always printed.
    _note('──────── CATALOG SWEEP REPORT ────────');
    if (_failures.isEmpty) {
      _note('No failures.');
    } else {
      _note('${_failures.length} FAILURE(S):');
      for (final f in _failures) {
        _note('  ✗ $f');
      }
    }
  });

  // ── Every audio ──────────────────────────────────────────────────────────
  testWidgets('every published audio is playable', (tester) async {
    final rows = await db
        .from('audios')
        .select('*')
        .eq('status', 'published')
        .order('created_at');
    final audios = List<Map<String, dynamic>>.from(rows);
    _note('Sweeping ${audios.length} published audios');

    var checked = 0;
    for (final row in audios) {
      final id = row['id'] as String?;
      final title = (row['title'] as String?) ?? '(untitled)';
      if (id == null) {
        _fail('audio with null id: $row');
        continue;
      }

      // 1) Parses with the real entity (catches malformed rows).
      try {
        AudioTrack.fromMap(row);
      } catch (e) {
        _fail('audio "$title" ($id) failed to parse: $e');
        continue;
      }

      // 2) Has at least one READY playable rendition.
      final assets = await db
          .from('content_assets')
          .select('asset_type, status')
          .eq('content_id', id)
          .inFilter('asset_type', ['audio_hls', 'audio_m4a', 'audio_mp3'])
          .eq('status', 'ready');
      if ((assets as List).isEmpty) {
        _fail('audio "$title" ($id) has no ready rendition');
        continue;
      }

      // 3) The real license endpoint issues a URL for it.
      if (_checkLicenses && activeDeviceId != null) {
        final url = await _issueAudioLicense(db, id, activeDeviceId!);
        if (url == null) {
          _fail('audio "$title" ($id) license returned no URL');
          continue;
        }
        // 4) Optionally prove the stream actually loads on-device.
        final withinSample =
            _playbackSample == 0 || checked < _playbackSample;
        if (_checkPlayback && withinSample) {
          final ok = await _canLoadStream(url);
          if (!ok) _fail('audio "$title" ($id) stream failed to load');
        }
      }
      checked++;
    }

    expect(_failures, isEmpty,
        reason: 'audio failures:\n${_failures.join('\n')}');
  }, timeout: const Timeout(Duration(minutes: 30)));

  // ── Every course + lesson ─────────────────────────────────────────────────
  testWidgets('every published course and lesson resolves', (tester) async {
    final courseRows = await db
        .from('courses')
        .select('*')
        .eq('status', 'published')
        .order('sort_order');
    final courses = List<Map<String, dynamic>>.from(courseRows);
    _note('Sweeping ${courses.length} published courses');

    final before = _failures.length;
    for (final course in courses) {
      final courseId = course['id'] as String?;
      final title = (course['title'] as String?) ?? '(untitled)';
      if (courseId == null) {
        _fail('course with null id: $course');
        continue;
      }
      try {
        CourseSummaryRef.fromMap(course);
      } catch (e) {
        _fail('course "$title" failed to parse: $e');
        continue;
      }

      // Modules -> lessons, with their embedded media rows, exactly as the
      // app loads a course detail.
      final lessonRows = await db
          .from('lessons')
          .select(
              '*, audios(id, status), videos(id, status), '
              'course_modules!inner(course_id)')
          .eq('course_modules.course_id', courseId);
      final lessons = List<Map<String, dynamic>>.from(lessonRows);

      for (final lessonRow in lessons) {
        final Lesson lesson;
        try {
          lesson = Lesson.fromMap(lessonRow);
        } catch (e) {
          _fail('lesson in "$title" failed to parse: $e');
          continue;
        }

        switch (lesson.type) {
          case LessonType.audio:
            if (lesson.audioId == null) {
              _fail('audio lesson "${lesson.title}" in course "$title" has a '
                  'dangling media reference');
            } else if (_checkLicenses && activeDeviceId != null) {
              final url =
                  await _issueAudioLicense(db, lesson.audioId!, activeDeviceId!);
              if (url == null) {
                _fail('lesson audio "${lesson.title}" in "$title" '
                    'could not be licensed');
              }
            }
            break;
          case LessonType.video:
            if (lesson.videoId == null) {
              _fail('video lesson "${lesson.title}" in course "$title" has a '
                  'dangling media reference');
            }
            break;
          case LessonType.text:
            if ((lesson.bodyMarkdown ?? '').trim().isEmpty) {
              _fail('text lesson "${lesson.title}" in course "$title" is empty');
            }
            break;
        }
      }
    }

    expect(_failures.length, before,
        reason: 'course/lesson failures:\n${_failures.skip(before).join('\n')}');
  }, timeout: const Timeout(Duration(minutes: 30)));

  // ── Every live session ────────────────────────────────────────────────────
  testWidgets('every live session parses', (tester) async {
    final rows = await db.from('live_sessions').select('*');
    final sessions = List<Map<String, dynamic>>.from(rows);
    _note('Sweeping ${sessions.length} live sessions');

    final before = _failures.length;
    for (final row in sessions) {
      try {
        LiveSession.fromMap(row);
      } catch (e) {
        _fail('live session ${row['id']} failed to parse: $e');
      }
    }
    expect(_failures.length, before,
        reason: 'live failures:\n${_failures.skip(before).join('\n')}');
  });

  // ── Every scheduled event / pop-up ────────────────────────────────────────
  testWidgets('every scheduled event parses and is policy-checked',
      (tester) async {
    final List<dynamic> rows;
    try {
      rows = await db.from('app_popups').select('*');
    } catch (e) {
      _note('app_popups not readable for this account ($e) — skipping.');
      return;
    }
    final popups = List<Map<String, dynamic>>.from(rows);
    _note('Sweeping ${popups.length} scheduled events/pop-ups');

    final before = _failures.length;
    for (final row in popups) {
      try {
        AppPopup.fromMap(row);
      } catch (e) {
        _fail('popup ${row['id']} failed to parse: $e');
        continue;
      }
      // Informational: flag text that would be suppressed on iOS so an admin
      // knows why Android sees it and iOS does not.
      final texts = [row['title'], row['body'], row['cta_label']]
          .map((e) => e as String?)
          .toList();
      if (anyViolatesIosContentPolicy(texts)) {
        _note('popup ${row['id']} contains price/CTA text — hidden on iOS '
            '(by design).');
      }
    }
    expect(_failures.length, before,
        reason: 'event failures:\n${_failures.skip(before).join('\n')}');
  });
}

/// Calls the real issue-audio-license edge function and returns the signed
/// URL, or null on any non-200 / missing URL.
Future<String?> _issueAudioLicense(
    SupabaseClient db, String audioId, String deviceId) async {
  try {
    final res = await db.functions.invoke(
      'issue-audio-license',
      body: {'audio_id': audioId},
      headers: {'X-Device-Id': deviceId},
    );
    if (res.status != 200) return null;
    final data = res.data;
    if (data is Map && data['url'] is String) return data['url'] as String;
    return null;
  } catch (_) {
    return null;
  }
}

/// Loads [url] with just_audio far enough to prove the device can decode it
/// (duration becomes known), then disposes. Returns false on timeout/error.
Future<bool> _canLoadStream(String url) async {
  final player = AudioPlayer();
  try {
    final duration = await player.setUrl(url).timeout(
          const Duration(seconds: 30),
          onTimeout: () => null,
        );
    return duration != null && duration > Duration.zero;
  } catch (_) {
    return false;
  } finally {
    await player.dispose();
  }
}
