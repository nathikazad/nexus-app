import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('lib/features has no direct nx_db imports', () {
    final dir = Directory('lib/features');
    expect(dir.existsSync(), isTrue);
    final offenders = <String>[];
    for (final entity in dir.listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final text = entity.readAsStringSync();
      if (text.contains('package:nx_db/')) {
        offenders.add(entity.path);
      }
    }
    expect(offenders, isEmpty, reason: offenders.join('\n'));
  });
}
