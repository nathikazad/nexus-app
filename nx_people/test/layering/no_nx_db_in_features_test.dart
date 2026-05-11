import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('features layer does not import nx_db directly', () {
    final featuresDir = Directory('lib/features');
    final dartFiles = featuresDir
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'));

    final offenders = <String>[];
    for (final file in dartFiles) {
      final contents = file.readAsStringSync();
      if (contents.contains("package:nx_db/")) {
        offenders.add(file.path);
      }
    }

    expect(offenders, isEmpty);
  });
}
