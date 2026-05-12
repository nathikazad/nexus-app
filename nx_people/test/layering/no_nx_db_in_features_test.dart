import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('features do not import KGQL, GraphQL, or nx_db internals', () {
    final featuresDir = Directory('lib/features');
    final dartFiles = featuresDir
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'));

    final offenders = <String>[];
    for (final file in dartFiles) {
      final contents = file.readAsStringSync();
      if (contents.contains('package:nx_db/kgql.dart') ||
          contents.contains('package:nx_db/riverpod.dart') ||
          contents.contains('package:nx_db/nx_db.dart') ||
          contents.contains('package:nx_db/src/') ||
          contents.contains('package:graphql_flutter/')) {
        offenders.add(file.path);
      }
    }

    expect(offenders, isEmpty);
  });
}
