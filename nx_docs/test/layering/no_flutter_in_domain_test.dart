import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('domain layer stays Flutter/Riverpod/nx_db free', () {
    final domainDir = Directory('lib/domain');
    final offenders = <String>[];
    for (final file in domainDir.listSync(recursive: true).whereType<File>()) {
      if (!file.path.endsWith('.dart')) {
        continue;
      }
      final text = file.readAsStringSync();
      if (text.contains('package:flutter/') ||
          text.contains('package:flutter_riverpod/') ||
          text.contains('package:nx_db/')) {
        offenders.add(file.path);
      }
    }
    expect(offenders, isEmpty);
  });
}
