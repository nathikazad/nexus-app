import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'lib/features may only import package:nx_db/auth.dart, person.dart, transcript.dart (no kgql/riverpod/nx_db)',
    () {
    final allowed = {
      "package:nx_db/auth.dart'",
      "package:nx_db/person.dart'",
      "package:nx_db/transcript.dart'",
    };
    final dir = Directory('lib/features');
    expect(dir.existsSync(), isTrue);
    final offenders = <String>[];
    for (final entity in dir.listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final text = entity.readAsStringSync();
      for (final line in text.split('\n')) {
        final t = line.trimLeft();
        if (!t.startsWith('import ') && !t.startsWith('export ')) continue;
        if (!t.contains('package:nx_db/')) continue;
        if (allowed.any((a) => t.contains(a))) continue;
        offenders.add('${entity.path}: $t');
      }
    }
    expect(offenders, isEmpty, reason: offenders.join('\n'));
  },
  );
}
