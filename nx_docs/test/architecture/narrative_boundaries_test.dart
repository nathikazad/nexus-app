import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _capabilities = <String>{
  'account',
  'app',
  'books',
  'companion',
  'documents',
  'library',
  'publishing',
  'settings',
  'sync',
  'tags',
  'workspace',
};

void main() {
  test(
    'the source tree uses product capabilities as its table of contents',
    () {
      final entries = Directory('lib').listSync();
      final directories = entries
          .whereType<Directory>()
          .map(
            (entry) =>
                entry.uri.pathSegments.where((part) => part.isNotEmpty).last,
          )
          .toSet();
      final rootFiles = entries
          .whereType<File>()
          .map((entry) => entry.uri.pathSegments.last)
          .toSet();

      expect(directories, _capabilities);
      expect(rootFiles, <String>{'main.dart'});
    },
  );

  test('obsolete framework-layer roots cannot return', () {
    for (final name in const <String>{
      'application',
      'composition',
      'core',
      'data',
      'domain',
      'features',
      'utils',
    }) {
      expect(Directory('lib/$name').existsSync(), isFalse, reason: name);
    }

    final offenders = _dartFiles(Directory('lib'))
        .where((file) {
          final source = file.readAsStringSync();
          return RegExp(
            r'package:nx_docs/(application|composition|core|data|domain|features|utils)/',
          ).hasMatch(source);
        })
        .map((file) => file.path)
        .toList();
    expect(offenders, isEmpty);
  });

  test('every capability exposes a same-named entry point', () {
    final missing = _capabilities
        .where((name) => !File('lib/$name/$name.dart').existsSync())
        .toList();
    expect(missing, isEmpty);
  });

  test('handwritten production files stay below the monolith threshold', () {
    final offenders = <String>[];
    for (final file in _dartFiles(Directory('lib'))) {
      if (file.path.endsWith('.g.dart')) continue;
      final lines = file.readAsLinesSync().length;
      if (lines > 1000) offenders.add('${file.path}: $lines lines');
    }
    expect(offenders, isEmpty);
  });

  test('application vocabulary is independent of UI and infrastructure', () {
    final vocabulary = <File>[
      File('lib/documents/document_models.dart'),
      File('lib/sync/sync_models.dart'),
      File('lib/tags/tag_system.dart'),
      File('lib/books/book_chapter.dart'),
      File('lib/companion/note_transcript.dart'),
    ];
    final offenders = _filesContainingAny(vocabulary, const <String>[
      'package:flutter/',
      'package:flutter_riverpod/',
      'package:nx_db/',
      'package:drift/',
      'package:http/',
      'package:graphql_flutter/',
    ]);
    expect(offenders, isEmpty);
  });

  test('Drift remains inside native synchronization adapters', () {
    final offenders =
        _filesContainingAny(_dartFiles(Directory('lib')), const <String>[
              'package:drift/',
              'package:drift_flutter/',
            ])
            .where(
              (path) =>
                  !path.startsWith('lib/sync/native/') &&
                  path != 'lib/sync/sync_providers.dart',
            )
            .toList();
    expect(offenders, isEmpty);
  });

  test('KGQL and GraphQL remain inside backend adapters', () {
    const adapterRoots = <String>[
      'lib/books/data/kgql/',
      'lib/companion/data/kgql/',
      'lib/documents/data/kgql/',
      'lib/publishing/data/',
      'lib/sync/remote/',
    ];
    final offenders = _filesContainingAny(
      _dartFiles(Directory('lib')),
      const <String>['package:nx_db/kgql.dart', 'package:graphql_flutter/'],
    ).where((path) => !adapterRoots.any(path.startsWith)).toList();
    expect(offenders, isEmpty);
  });

  test('documents stay independent of Book Chapter behavior', () {
    final offenders = _dartFiles(Directory('lib/documents'))
        .where((file) {
          final source = file.readAsStringSync();
          return source.contains('BookChapter') || source.contains('/books/');
        })
        .map((file) => file.path)
        .toList();
    expect(offenders, isEmpty);
  });

  test('live conversation accepts generic references', () {
    final source = File(
      'lib/companion/conversation/conversation_controller.dart',
    ).readAsStringSync();
    expect(source, contains('ConversationReference'));
    expect(source, isNot(contains('BookChapter')));
  });
}

Iterable<File> _dartFiles(Directory directory) sync* {
  if (!directory.existsSync()) return;
  for (final entity in directory.listSync(recursive: true)) {
    if (entity is File && entity.path.endsWith('.dart')) yield entity;
  }
}

List<String> _filesContainingAny(Iterable<File> files, List<String> needles) {
  final offenders = <String>[];
  for (final file in files) {
    final source = file.readAsStringSync();
    if (needles.any(source.contains)) offenders.add(file.path);
  }
  return offenders..sort();
}
