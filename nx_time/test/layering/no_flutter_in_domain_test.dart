import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('lib/domain avoids Flutter, Riverpod, and nx_db', () {
    final dir = Directory('lib/domain');
    expect(dir.existsSync(), isTrue);
    const forbidden = [
      'package:flutter/',
      'package:flutter_riverpod/',
      'package:nx_db/',
    ];
    final offenders = <String>[];
    for (final entity in dir.listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final text = entity.readAsStringSync();
      for (final f in forbidden) {
        if (text.contains(f)) {
          offenders.add('${entity.path}: $f');
        }
      }
    }
    expect(offenders, isEmpty, reason: offenders.join('\n'));
  });
}
