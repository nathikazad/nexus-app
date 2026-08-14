import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('handwritten production files stay below the monolith threshold', () {
    final offenders = <String>[];
    for (final file in _dartFiles(Directory('lib'))) {
      final lines = file.readAsLinesSync().length;
      if (lines > 1000) offenders.add('${file.path}: $lines lines');
    }
    expect(offenders, isEmpty);
  });

  test('document vocabulary is independent of UI and infrastructure', () {
    final source = File(
      'lib/documents/document_content.dart',
    ).readAsStringSync();
    for (final dependency in const <String>[
      'package:flutter/',
      'package:graphql_flutter/',
      'package:nx_db/',
    ]) {
      expect(source, isNot(contains(dependency)), reason: dependency);
    }
  });

  test('KGQL and GraphQL remain inside the backend adapter', () {
    final offenders = _dartFiles(Directory('lib'))
        .where((file) {
          final source = file.readAsStringSync();
          final usesBackend =
              source.contains('package:nx_db/') ||
              source.contains('package:graphql_flutter/');
          return usesBackend &&
              !file.path.startsWith('lib/documents/data/kgql/');
        })
        .map((file) => file.path)
        .toList();
    expect(offenders, isEmpty);
  });
}

Iterable<File> _dartFiles(Directory directory) sync* {
  if (!directory.existsSync()) return;
  for (final entity in directory.listSync(recursive: true)) {
    if (entity is File && entity.path.endsWith('.dart')) yield entity;
  }
}
