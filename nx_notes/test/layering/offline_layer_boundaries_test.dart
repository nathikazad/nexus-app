import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('application layer stays pure Dart and depends only on domain', () {
    final offenders =
        _filesContainingAny(Directory('lib/application'), const <String>[
          'package:flutter/',
          'package:flutter_riverpod/',
          'package:nx_db/',
          'package:graphql_flutter/',
          'package:drift/',
          'package:nx_notes/data/',
          'package:nx_notes/features/',
          'dart:io',
        ]);
    expect(offenders, isEmpty);
  });

  test('data layer does not import features', () {
    expect(
      _filesContainingAny(Directory('lib/data'), const <String>[
        'package:nx_notes/features/',
      ]),
      isEmpty,
    );
  });

  test('features add no new direct data-layer dependencies', () {
    const transitionalAllowlist = <String>{
      'lib/features/desktop/desktop_shell.dart',
      'lib/features/document/document_actions.dart',
      'lib/features/editor/document_editor_view.dart',
      'lib/features/mobile/mobile_shell.dart',
      'lib/features/shell/notes_root_shell.dart',
    };
    final offenders = _filesContainingAny(
      Directory('lib/features'),
      const <String>['package:nx_notes/data/'],
    ).toSet();
    expect(offenders.difference(transitionalAllowlist), isEmpty);
  });

  test('KGQL and GraphQL add no new dependencies outside remote adapters', () {
    const transitionalAllowlist = <String>{
      'lib/data/document/document_mapper.dart',
      'lib/data/document/document_schema_provider.dart',
      'lib/data/document/kgql_document_repository.dart',
    };
    final offenders = _filesContainingAny(Directory('lib'), const <String>[
      'package:nx_db/kgql.dart',
      'package:graphql_flutter/',
    ]).where((path) => !path.startsWith('lib/data/remote/kgql/')).toSet();
    expect(offenders.difference(transitionalAllowlist), isEmpty);
  });

  test('Drift is confined to its local adapter', () {
    final offenders = _filesContainingAny(Directory('lib'), const <String>[
      'package:drift/',
    ]).where((path) => !path.startsWith('lib/data/local/drift/')).toList();
    expect(offenders, isEmpty);
  });
}

List<String> _filesContainingAny(Directory directory, List<String> needles) {
  if (!directory.existsSync()) return const <String>[];
  final offenders = <String>[];
  for (final file in directory.listSync(recursive: true).whereType<File>()) {
    if (!file.path.endsWith('.dart')) continue;
    final text = file.readAsStringSync();
    if (needles.any(text.contains)) {
      offenders.add(file.path);
    }
  }
  return offenders..sort();
}
