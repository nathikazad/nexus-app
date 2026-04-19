import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('lib/data avoids importing features', () {
    final dir = Directory('lib/data');
    expect(dir.existsSync(), isTrue);
    const forbidden = 'package:nexus_voice_assistant/features/';
    final offenders = <String>[];
    for (final entity in dir.listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final text = entity.readAsStringSync();
      if (text.contains(forbidden)) {
        offenders.add(entity.path);
      }
    }
    expect(offenders, isEmpty, reason: offenders.join('\n'));
  });
}
