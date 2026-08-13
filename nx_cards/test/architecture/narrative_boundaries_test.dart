import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('top-level folders name the card-learning story', () {
    const allowed = <String>{
      'account',
      'app',
      'audio',
      'browser',
      'scheduling',
      'settings',
      'study',
      'sync',
      'tutor',
    };
    final actual = Directory('lib')
        .listSync()
        .whereType<Directory>()
        .map(
          (directory) => directory.uri.pathSegments
              .where((segment) => segment.isNotEmpty)
              .last,
        )
        .where((name) => !name.startsWith('.'))
        .toSet();

    expect(actual.difference(allowed), isEmpty);
  });

  test('application-ready cards are framework and persistence independent', () {
    expect(
      _filesContainingAny(Directory('lib/browser/data/models'), const <String>[
        'package:flutter/',
        'package:flutter_riverpod/',
        'package:nx_db/',
        'package:graphql_flutter/',
        'package:drift/',
        'package:http/',
        'package:nx_live_agent/',
      ]),
      isEmpty,
    );
  });

  test('browser folders expose the ways a person navigates cards', () {
    const expected = <String>{'card_list', 'data', 'language'};
    final actual = Directory('lib/browser')
        .listSync()
        .whereType<Directory>()
        .map(
          (directory) => directory.uri.pathSegments
              .where((segment) => segment.isNotEmpty)
              .last,
        )
        .toSet();
    expect(actual, expected);

    final dataFolders = Directory('lib/browser/data')
        .listSync()
        .whereType<Directory>()
        .map(
          (directory) => directory.uri.pathSegments
              .where((segment) => segment.isNotEmpty)
              .last,
        )
        .toSet();
    expect(dataFolders, const <String>{'kgql', 'models'});
  });

  test('KGQL and GraphQL stay in KGQL or sync network adapters', () {
    final offenders =
        _filesContainingAny(Directory('lib'), const <String>[
          'package:nx_db/kgql.dart',
          'package:graphql_flutter/',
        ]).where(
          (path) =>
              !path.startsWith('lib/browser/data/kgql/') &&
              !path.startsWith('lib/sync/remote/'),
        );
    expect(offenders, isEmpty);
  });

  test('Drift stays in native sync adapters or sync assembly', () {
    final offenders =
        _filesContainingAny(Directory('lib'), const <String>[
          'package:drift/',
          'package:drift_flutter/',
        ]).where(
          (path) =>
              !path.startsWith('lib/sync/native/') &&
              path != 'lib/sync/sync_providers.dart',
        );
    expect(offenders, isEmpty);
  });

  test('live-agent details stay in tutor or app startup', () {
    final offenders =
        _filesContainingAny(Directory('lib'), const <String>[
          'package:nx_live_agent/',
        ]).where(
          (path) => !path.startsWith('lib/tutor/') && path != 'lib/main.dart',
        );
    expect(offenders, isEmpty);
  });

  test('app contains only the Flutter root, routes, and theme', () {
    const expected = <String>{'recall_app.dart', 'routes.dart', 'theme.dart'};
    final actual = Directory('lib/app')
        .listSync()
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'))
        .map((file) => file.uri.pathSegments.last)
        .toSet();
    expect(actual, expected);
  });

  test('study details are grouped by learning flow', () {
    const expectedFolders = <String>{'language', 'session'};
    final actualFolders = Directory('lib/study')
        .listSync()
        .whereType<Directory>()
        .map(
          (directory) => directory.uri.pathSegments
              .where((segment) => segment.isNotEmpty)
              .last,
        )
        .toSet();
    expect(actualFolders, expectedFolders);

    final languageFolders = Directory('lib/study/language')
        .listSync()
        .whereType<Directory>()
        .map(
          (directory) => directory.uri.pathSegments
              .where((segment) => segment.isNotEmpty)
              .last,
        )
        .toSet();
    expect(languageFolders, const <String>{'drawing'});

    const expectedRootFiles = <String>{
      'study.dart',
      'study_queue.dart',
      'study_setup_page.dart',
    };
    final actualRootDartFiles = Directory('lib/study')
        .listSync()
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'))
        .map((file) => file.uri.pathSegments.last)
        .toSet();
    expect(actualRootDartFiles, expectedRootFiles);
  });
}

List<String> _filesContainingAny(Directory directory, List<String> needles) {
  final offenders = <String>[];
  for (final file in directory.listSync(recursive: true).whereType<File>()) {
    if (!file.path.endsWith('.dart')) continue;
    final text = file.readAsStringSync();
    if (needles.any(text.contains)) offenders.add(file.path);
  }
  return offenders..sort();
}
