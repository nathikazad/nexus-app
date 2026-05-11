import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('domain layer does not import Flutter', () {
    final domainDir = Directory('lib/domain');
    final dartFiles = domainDir
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'));

    final offenders = <String>[];
    for (final file in dartFiles) {
      final contents = file.readAsStringSync();
      if (contents.contains("package:flutter/")) {
        offenders.add(file.path);
      }
    }

    expect(offenders, isEmpty);
  });
}
