import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Document domain and data code stay unaware of Book Chapter', () {
    final offenders =
        <String>[
          ..._dartFiles(Directory('lib/domain/document')),
          ..._dartFiles(Directory('lib/data/document')),
        ].where((path) {
          final text = File(path).readAsStringSync();
          return text.contains('domain/book/') || text.contains('BookChapter');
        }).toList();

    expect(offenders, isEmpty);
  });

  test('the live controller accepts generic references, not chapters', () {
    final text = File(
      'lib/features/live_conversation/note_live_conversation_controller.dart',
    ).readAsStringSync();

    expect(text, contains('ConversationReference'));
    expect(text, isNot(contains('BookChapter')));
  });
}

Iterable<String> _dartFiles(Directory directory) => directory
    .listSync(recursive: true)
    .whereType<File>()
    .where((file) => file.path.endsWith('.dart'))
    .map((file) => file.path);
