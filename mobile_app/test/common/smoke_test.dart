import 'package:flutter_test/flutter_test.dart';

import 'fixtures.dart';

/// Phase 1 smoke test.
///
/// Its only job is to prove the test harness, dependencies and CI wiring
/// run end to end before any real module tests land. Phases 2+ replace the
/// bulk of this file's purpose with behavior tests under the sibling
/// folders (auth/, router/, courses/, ...).
void main() {
  test('test harness runs', () {
    expect(true, isTrue);
  });

  test('fixtures build the shapes the data layer parses', () {
    final standalone = audioRow();
    expect(standalone['id'], 'audio-1');
    expect(standalone.containsKey('lessons'), isFalse);

    final courseAudio = audioRow(lessons: lessonLink());
    expect(courseAudio['lessons'], isA<List>());
    expect((courseAudio['lessons'] as List).single['id'], 'lesson-1');
  });
}
