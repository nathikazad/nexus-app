import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('stable barrel does not export concrete database implementations', () {
    final barrel = File('lib/nx_offline.dart').readAsStringSync();

    expect(barrel, isNot(contains('drift_sync_store.dart')));
    expect(barrel, isNot(contains('sync_database.dart')));
    expect(barrel, isNot(contains('sync_coordinator.dart')));
    expect(barrel, isNot(contains('kgql_sync_transport.dart')));
  });

  test('shared implementation has no application imports', () {
    expect(
      _filesContainingAny(Directory('lib'), const [
        'package:nx_notes/',
        'package:nx_expense/',
        'package:nx_time/',
        'package:nx_main/',
      ]),
      isEmpty,
    );
  });

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

  test('persistence modules do not import Flutter presentation', () {
    expect(
      _filesContainingAny(Directory('lib/src/persistence'), const [
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
