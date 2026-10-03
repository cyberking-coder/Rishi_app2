import 'package:flutter_test/flutter_test.dart';
import 'package:meditation_app/features/chat/domain/entities/chat_message.dart';

/// The assistant reply parser pulls app:// links out of prose. It must only
/// accept uuid-shaped ids (a hallucinated slug would route to an empty
/// screen), keep the human label in the sentence, and dedupe repeats.
void main() {
  const uuid = '11111111-2222-3333-4444-555555555555';
  const uuid2 = 'aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee';

  test('extracts an audio link and strips the markdown, keeping the label', () {
    final m = ChatMessage.assistant(
      'Try [Morning Stillness](app://audio/$uuid) today.',
    );
    expect(m.role, ChatRole.assistant);
    expect(m.text, 'Try Morning Stillness today.');
    expect(m.links.length, 1);
    expect(m.links.single.kind, 'audio');
    expect(m.links.single.id, uuid);
    expect(m.links.single.route, '/audio/$uuid');
  });

  test('course link routes to /course', () {
    final m = ChatMessage.assistant('[Awaken](app://course/$uuid)');
    expect(m.links.single.route, '/course/$uuid');
  });

  test('ignores non-uuid ids and unknown kinds', () {
    final m = ChatMessage.assistant(
      'Bad [x](app://audio/not-a-uuid) and [y](app://video/$uuid).',
    );
    expect(m.links, isEmpty);
    // Non-matching text is left untouched.
    expect(m.text.contains('app://'), isTrue);
  });

  test('dedupes the same link mentioned twice', () {
    final m = ChatMessage.assistant(
      '[A](app://audio/$uuid) and again [A2](app://audio/$uuid) '
      'plus [B](app://course/$uuid2)',
    );
    expect(m.links.length, 2);
    expect(m.links.map((l) => l.id).toSet(), {uuid, uuid2});
  });

  test('user message carries text and no links', () {
    final m = ChatMessage.user('hello');
    expect(m.role, ChatRole.user);
    expect(m.links, isEmpty);
  });

  test('copyWith toggles pending/error without losing links', () {
    final m = ChatMessage.assistant('[A](app://audio/$uuid)');
    final p = m.copyWith(pending: true);
    expect(p.pending, isTrue);
    expect(p.links.length, 1);
    final e = m.copyWith(error: 'failed');
    expect(e.error, 'failed');
  });
}
