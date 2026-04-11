@Tags(['integration'])
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:test/test.dart' show Tags;

import 'package:nx_db/nx_db.dart';
import 'package:nx_db/src/data_providers/model_types_provider.dart';
import 'package:nx_db/src/data_providers/models_provider.dart';

/// Same as [getAllModelTypesQuery] plus `traits` so trait types (e.g. Employee) appear.
const _getAllModelTypesWithTraitsQuery = '''
query GetAllModelTypesWithTraits {
  getKgqlModelType(input: {
    model_types: []
    struct: {
      id: true
      name: true
      type_kind: true
      description: true
      parent: true
      children: true
      traits: true
    }
  })
}
''';

// ---------------------------------------------------------------------------
// Expected shapes from servers/pgdb/docs/llm-reference/seed-data.md
// (setup_model_types + setup_tag_systems for Expense)
// ---------------------------------------------------------------------------

/// Abstract / base / trait / action types from seed `setup_model_types`.
const _kSeedModelTypeNames = <String>{
  'Real Nouns',
  'Digital Nouns',
  'Action',
  'Person',
  'Company',
  'Place',
  'Event',
  'Expense',
  'Contact',
  'Transcript',
  'Recipe',
  'Essay',
  'Employee',
  'Meet',
  'Goto',
  'Prayer',
  'Meal',
  'Meditation',
  'Workout',
  'Alcohol',
  'Sleep',
};

/// Expense tag systems from seed `setup_expense_tag_systems`.
const _kExpenseTagSystemNames = {'Category', 'Judgment', 'Essentiality'};

/// Category root nodes (seed doc).
const _kCategoryRootNames = {'Food', 'Travel', 'Business', 'Entertainment'};

bool get _runIntegration => Platform.environment['RUN_NX_DB_INTEGRATION'] == 'true';

GraphQLClient _client() {
  final fromEnv = Platform.environment['NX_DB_INTEGRATION_GRAPHQL_HTTP'];
  final graphqlHttp = (fromEnv != null && fromEnv.isNotEmpty)
      ? fromEnv
      : kIntegrationTestBackendUrls.graphqlHttp;
  final userId = Platform.environment['NX_DB_INTEGRATION_USER_ID'] ?? '1';
  return createClient(graphqlHttp, userId);
}

void _collectModelTypeNames(ModelType mt, Set<String> out) {
  out.add(mt.name);
  for (final c in mt.children ?? const <ModelType>[]) {
    _collectModelTypeNames(c, out);
  }
  for (final t in mt.traits ?? const <ModelType>[]) {
    _collectModelTypeNames(t, out);
  }
}

ModelType? _findModelTypeByName(ModelType mt, String name) {
  if (mt.name == name) return mt;
  for (final c in mt.children ?? const <ModelType>[]) {
    final found = _findModelTypeByName(c, name);
    if (found != null) return found;
  }
  for (final t in mt.traits ?? const <ModelType>[]) {
    final found = _findModelTypeByName(t, name);
    if (found != null) return found;
  }
  return null;
}

ModelType? _findInForest(Iterable<ModelType> roots, String name) {
  for (final r in roots) {
    final found = _findModelTypeByName(r, name);
    if (found != null) return found;
  }
  return null;
}

void _collectTagNodeNames(TagNode n, Set<String> out) {
  out.add(n.name);
  for (final c in n.children ?? const <TagNode>[]) {
    _collectTagNodeNames(c, out);
  }
}

Future<List<ModelType>> _fetchModelTypeRoots(GraphQLClient client) async {
  final result = await client.query(
    QueryOptions(
      document: gql(_getAllModelTypesWithTraitsQuery),
      fetchPolicy: FetchPolicy.networkOnly,
    ),
  );
  expect(result.hasException, isFalse, reason: '${result.exception}');
  final raw = result.data?['getKgqlModelType'];
  expect(raw, isNotNull);
  final list = raw is String ? json.decode(raw) as List<dynamic> : raw! as List<dynamic>;
  return list
      .map((e) => ModelType.fromJson(e as Map<String, dynamic>, recursive: true))
      .toList();
}

Future<ModelType?> _fetchModelTypeById(GraphQLClient client, int id) async {
  final result = await client.query(
    QueryOptions(
      document: gql(getModelTypeByIdQuery),
      variables: {
        'input': {
          'model_types': [id],
          'struct': {
            'id': true,
            'name': true,
            'type_kind': true,
            'description': true,
            'parent': true,
            'children': true,
            'traits': true,
            'attributes': true,
            'relations': true,
            // Same shape as [modelTypeProvider] — server fills nested tag nodes.
            'tag_systems': true,
          },
        },
      },
      fetchPolicy: FetchPolicy.networkOnly,
    ),
  );
  expect(result.hasException, isFalse, reason: '${result.exception}');
  final raw = result.data?['getKgqlModelType'];
  if (raw == null) return null;
  final list = raw is String ? json.decode(raw) as List<dynamic> : raw as List<dynamic>;
  if (list.isEmpty) return null;
  return ModelType.fromJson(list.first as Map<String, dynamic>, recursive: true);
}

void main() {
  group('Seed data schema (llm-reference/seed-data.md)', () {
    late GraphQLClient client;

    setUpAll(() {
      client = _client();
    });

    test('model type tree contains expected names', () async {
      final roots = await _fetchModelTypeRoots(client);
      expect(roots, isNotEmpty);
      final names = <String>{};
      for (final r in roots) {
        _collectModelTypeNames(r, names);
      }
      for (final expected in _kSeedModelTypeNames) {
        expect(names, contains(expected), reason: 'Missing model type "$expected" — seed / API mismatch');
      }
    });

    test('Expense type: cost, relation to Company, tag systems', () async {
      final roots = await _fetchModelTypeRoots(client);
      final expense = _findInForest(roots, 'Expense');
      expect(expense, isNotNull, reason: 'Expense model type not found in tree');

      final detailed = await _fetchModelTypeById(client, expense!.id);
      expect(detailed, isNotNull);
      final mt = detailed!;

      final attrKeys = mt.attributes?.map((a) => a.key).whereType<String>().toSet() ?? {};
      expect(attrKeys, contains('cost'), reason: 'Expense should define `cost` (seed-data § attributes)');

      final links = mt.relations?.map((r) => r.link?.toString()).whereType<String>().toSet() ?? {};
      expect(links, contains('Company'), reason: 'Expense should relate to Company (`expense_for` target)');

      final tagNames = mt.tagSystems?.map((s) => s.name).toSet() ?? {};
      for (final n in _kExpenseTagSystemNames) {
        expect(tagNames, contains(n), reason: 'Missing Expense tag system "$n"');
      }

      final categoryList = mt.tagSystems?.where((s) => s.name == 'Category').toList() ?? [];
      expect(categoryList.length, 1, reason: 'Single Category tag system expected');
      final category = categoryList.first;
      final catNames = <String>{};
      for (final node in category.nodes) {
        _collectTagNodeNames(node, catNames);
      }
      for (final root in _kCategoryRootNames) {
        expect(catNames, contains(root), reason: 'Category tree should include root "$root"');
      }
    });

    test('Person type: age attribute (seed-data)', () async {
      final roots = await _fetchModelTypeRoots(client);
      final person = _findInForest(roots, 'Person');
      expect(person, isNotNull);

      final detailed = await _fetchModelTypeById(client, person!.id);
      expect(detailed, isNotNull);
      final keys = detailed!.attributes?.map((a) => a.key).whereType<String>().toSet() ?? {};
      expect(keys, contains('age'));
    });

    test('Expense models: rows parse; at least one has cost', () async {
      final result = await client.query(
        QueryOptions(
          document: gql(getModelsByModelTypeIdQuery),
          variables: {
            'filter': {'model_type': 'Expense'},
            'struct': {
              'id': true,
              'name': true,
              'model_type_id': true,
              'attributes': {
                'id': true,
                'key': true,
                'value': true,
              },
            },
          },
          fetchPolicy: FetchPolicy.networkOnly,
        ),
      );
      expect(result.hasException, isFalse, reason: '${result.exception}');
      final raw = result.data?['getKgqlModels'];
      expect(raw, isNotNull);
      final list = raw is String ? json.decode(raw) as List<dynamic> : raw as List<dynamic>;
      expect(list, isNotEmpty, reason: 'Seed demo should include Expense models');

      final models = list
          .map((e) => Model.fromJson(e as Map<String, dynamic>))
          .toList();

      var anyCost = false;
      for (final m in models) {
        final fromMap = m.attributes?['cost'];
        if (fromMap != null) {
          anyCost = true;
          break;
        }
        final fromList = m.attributesList?.where((a) => a.key == 'cost').toList();
        if (fromList != null && fromList.isNotEmpty) {
          anyCost = true;
          break;
        }
      }
      expect(anyCost, isTrue, reason: 'At least one Expense model should expose `cost` (seed-data § Expenses)');
    });
  }, skip: !_runIntegration);
}
