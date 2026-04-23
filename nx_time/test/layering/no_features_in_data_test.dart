import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('lib/data/ must not import package:nx_time/features/ (keeps data layer free of feature UI state)', () {
    final dir = Directory('lib/data');
    expect(dir.existsSync(), isTrue);
    final offenders = <String>[];
    for (final entity in dir.listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final text = entity.readAsStringSync();
      for (final line in text.split('\n')) {
        final t = line.trimLeft();
        if (!t.startsWith('import ') && !t.startsWith('export ')) continue;
        if (t.contains("package:nx_time/features/")) {
          offenders.add('${entity.path}: $t');
        }
      }
    }
    expect(offenders, isEmpty, reason: offenders.join('\n'));
  });
}
