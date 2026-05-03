import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('features do not import KGQL, GraphQL, or nx_db internals', () {
    final featuresDir = Directory('lib/features');
    final offenders = <String>[];
    for (final file in featuresDir.listSync(recursive: true).whereType<File>()) {
      if (!file.path.endsWith('.dart')) {
        continue;
      }
      final text = file.readAsStringSync();
      if (text.contains('package:nx_db/kgql.dart') ||
          text.contains('package:nx_db/riverpod.dart') ||
          text.contains('package:nx_db/nx_db.dart') ||
          text.contains('package:nx_db/src/') ||
          text.contains('package:graphql_flutter/')) {
        offenders.add(file.path);
      }
    }
    expect(offenders, isEmpty);
  });
}
