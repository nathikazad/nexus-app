import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('core and sync modules remain framework independent', () {
    final offenders = <String>[
      ..._filesContainingAny(Directory('lib/src/core'), const [
        'package:flutter/',
        'package:drift/',
        'package:http/',
        'package:shared_preferences/',
        'package:nx_db/',
      ]),
      ..._filesContainingAny(Directory('lib/src/sync'), const [
        'package:flutter/',
        'package:drift/',
        'package:http/',
        'package:shared_preferences/',
        'package:nx_db/',
      ]),
    ]..sort();

    expect(offenders, isEmpty);
  });

  test('storage and KGQL modules do not import Flutter presentation', () {
    expect(
      _filesContainingAny(Directory('lib/src/storage'), const [
        'package:flutter/',
        'src/flutter/',
      ]),
      isEmpty,
    );
    expect(
      _filesContainingAny(Directory('lib/src/kgql'), const [
        'package:flutter/',
        'src/flutter/',
      ]),
      isEmpty,
    );
  });
}

List<String> _filesContainingAny(Directory directory, List<String> needles) {
  if (!directory.existsSync()) return const [];
  final offenders = <String>[];
  for (final file in directory.listSync(recursive: true).whereType<File>()) {
    if (!file.path.endsWith('.dart')) continue;
    final text = file.readAsStringSync();
    if (needles.any(text.contains)) offenders.add(file.path);
  }
  return offenders;
}
