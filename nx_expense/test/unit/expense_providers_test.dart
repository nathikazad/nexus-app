import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nx_db/nx_db.dart';
import 'package:nx_expense/data/providers.dart';
import 'package:nx_expense/domain/expense/expense_filter.dart';
import 'package:nx_expense/features/expense/expense_dashboard_view_model.dart';

class _MockGraphQLClient extends Mock implements GraphQLClient {}

DateTimeRange _testMonth(int year, int month) {
  final start = DateTime(year, month);
  final end = DateTime(year, month + 1).subtract(const Duration(days: 1));
  return DateTimeRange(start: start, end: end);
}

QueryResult _qr(Map<String, dynamic>? data) {
  return QueryResult(
    options: QueryOptions(document: gql('query { __typename }')),
    source: QueryResultSource.network,
    data: data,
  );
}

Map<String, dynamic> _expenseMtJson({bool extraAttr = false}) {
  final attrs = <Map<String, dynamic>>[
    {'key': 'cost', 'value_type': 'number'},
  ];
  if (extraAttr) {
    attrs.add({'key': 'note', 'value_type': 'string'});
  }
  return {
    'id': 9,
    'name': 'Expense',
    'attributes': attrs,
    'relations': [
      {'target_model_type': 'Company'},
    ],
    'tag_systems': [
      {
        'id': 1,
        'name': 'Category',
        'is_hierarchical': false,
        'selection_mode': 'multiple',
        'nodes': [],
      },
    ],
  };
}

void main() {
  setUpAll(() {
    registerFallbackValue(
      QueryOptions(document: gql('query { __typename }')),
    );
  });

  group('P7 providers (mocked client)', () {
    test('P7.1 expenseStructProvider matches S5 expectations from fixture', () async {
      final fixture = ModelType.fromJson(_expenseMtJson(), recursive: true);
      final container = ProviderContainer(
        overrides: [
          expenseSchemaProvider.overrideWith((ref) async => fixture),
        ],
      );
      addTearDown(container.dispose);
      await container.read(expenseSchemaProvider.future);
      final struct = container.read(expenseStructProvider);
      expect(struct['cost'], true);
      expect(struct['tags'], true);
      expect(struct['Company'], {'id': true, 'name': true});
    });

    test('P7.2 expenseListProvider — models and modelTypeId', () async {
      final mock = _MockGraphQLClient();
      var call = 0;
      when(() => mock.query(any())).thenAnswer((_) async {
        call++;
        if (call == 1) {
          return _qr({'getKgqlModelType': [_expenseMtJson()]});
        }
        if (call == 2) {
          return _qr({
            'getKgqlModels': [
              {
                'id': 101,
                'name': 'Coffee',
                'model_type_id': 9,
              },
            ],
          });
        }
        throw StateError('unexpected call $call');
      });

      final container = ProviderContainer(
        overrides: [graphqlClientProvider.overrideWithValue(mock)],
      );
      addTearDown(container.dispose);

      final list = await container.read(
        expenseListProvider((filter: null, dateRange: _testMonth(2024, 6))).future,
      );
      expect(list.length, 1);
      expect(list.first.modelTypeId, 9);
      expect(list.first.name, 'Coffee');
    });

    test('P7.2b expenseListProvider — filters use date attribute YYYY-MM-DD', () async {
      final mock = _MockGraphQLClient();
      final captured = <QueryOptions>[];
      var call = 0;
      when(() => mock.query(any())).thenAnswer((inv) async {
        captured.add(inv.positionalArguments[0] as QueryOptions);
        call++;
        if (call == 1) {
          return _qr({'getKgqlModelType': [_expenseMtJson()]});
        }
        if (call == 2) {
          return _qr({'getKgqlModels': []});
        }
        throw StateError('unexpected call $call');
      });

      final container = ProviderContainer(
        overrides: [graphqlClientProvider.overrideWithValue(mock)],
      );
      addTearDown(container.dispose);

      await container.read(
        expenseListProvider((filter: null, dateRange: _testMonth(2024, 6))).future,
      );

      expect(captured.length, 2);
      final filter = captured[1].variables['filter'] as Map<String, dynamic>;
      final filters = filter['filters'] as List<dynamic>;
      expect(filters.length, 2);
      expect(filters[0], {'key': 'date', 'op': '>=', 'value': '2024-06-01'});
      expect(filters[1], {'key': 'date', 'op': '<=', 'value': '2024-06-30'});
    });

    test('P7.3 expenseListProvider — tag_filters in variables', () async {
      final mock = _MockGraphQLClient();
      final captured = <QueryOptions>[];
      var call = 0;
      when(() => mock.query(any())).thenAnswer((inv) async {
        captured.add(inv.positionalArguments[0] as QueryOptions);
        call++;
        if (call == 1) {
          return _qr({'getKgqlModelType': [_expenseMtJson()]});
        }
        if (call == 2) {
          return _qr({'getKgqlModels': []});
        }
        throw StateError('unexpected call $call');
      });

      final container = ProviderContainer(
        overrides: [graphqlClientProvider.overrideWithValue(mock)],
      );
      addTearDown(container.dispose);

      await container.read(
        expenseListProvider((
          filter: const ExpenseFilter(
            tagFilters: [
              {'system': 'Category', 'node': 'Coffee', 'include_descendants': true},
            ],
          ),
          dateRange: _testMonth(2024, 6),
        )).future,
      );

      expect(captured.length, 2);
      final filter = captured[1].variables['filter'] as Map<String, dynamic>;
      expect(filter['tag_filters'], isNotNull);
      expect((filter['tag_filters'] as List).length, 1);
    });

    test('P7.4 expenseDetailProvider — id filter eq 42', () async {
      final mock = _MockGraphQLClient();
      final captured = <QueryOptions>[];
      var call = 0;
      when(() => mock.query(any())).thenAnswer((inv) async {
        captured.add(inv.positionalArguments[0] as QueryOptions);
        call++;
        if (call == 1) {
          return _qr({'getKgqlModelType': [_expenseMtJson()]});
        }
        if (call == 2) {
          return _qr({
            'getKgqlModels': [
              {'id': 42, 'name': 'X', 'model_type_id': 9},
            ],
          });
        }
        throw StateError('unexpected call $call');
      });

      final container = ProviderContainer(
        overrides: [graphqlClientProvider.overrideWithValue(mock)],
      );
      addTearDown(container.dispose);

      await container.read(expenseDetailProvider(42).future);

      final vars = captured[1].variables;
      final filter = vars['filter'] as Map<String, dynamic>;
      final filters = filter['filters'] as List;
      expect(filters.first['value'], '42');
      expect(filters.first['op'], '=');
    });

    test('P7.5 expenseSummaryProvider — aggregate key from schema (cost)', () async {
      final mock = _MockGraphQLClient();
      final aggregates = <Map<String, dynamic>>[];
      var call = 0;
      when(() => mock.query(any())).thenAnswer((inv) async {
        final o = inv.positionalArguments[0] as QueryOptions;
        call++;
        if (o.variables.containsKey('input')) {
          return _qr({'getKgqlModelType': [_expenseMtJson()]});
        }
        if (o.variables.containsKey('filterkgql')) {
          aggregates.add(Map<String, dynamic>.from(o.variables['aggregate'] as Map));
          if (call == 2) {
            return _qr({'getKgqlAggregate': '{"aggregated_value": 7}'});
          }
          if (call == 3) {
            return _qr({'getKgqlAggregate': '{"aggregated_value": 100.5}'});
          }
        }
        throw StateError('unexpected call $call');
      });

      final container = ProviderContainer(
        overrides: [graphqlClientProvider.overrideWithValue(mock)],
      );
      addTearDown(container.dispose);

      await container.read(expenseSummaryProvider.future);

      expect(aggregates.length, 2);
      expect(aggregates[0]['metric'], 'count');
      expect(aggregates[1]['metric'], 'sum');
      expect(aggregates[1]['key'], 'cost');
    });

    test('P7.6 spendByTagSystemProvider — group key tag:Category', () async {
      final mock = _MockGraphQLClient();
      Map<String, dynamic>? agg;
      var call = 0;
      when(() => mock.query(any())).thenAnswer((inv) async {
        final o = inv.positionalArguments[0] as QueryOptions;
        call++;
        if (o.variables.containsKey('input')) {
          return _qr({'getKgqlModelType': [_expenseMtJson()]});
        }
        if (o.variables.containsKey('filterkgql')) {
          agg = o.variables['aggregate'] as Map<String, dynamic>?;
          return _qr({'getKgqlAggregate': '{"aggregated_value": 0}'});
        }
        throw StateError('unexpected call $call');
      });

      final container = ProviderContainer(
        overrides: [graphqlClientProvider.overrideWithValue(mock)],
      );
      addTearDown(container.dispose);

      await container.read(spendByTagSystemProvider((
        systemName: 'Category',
        parentNode: null,
        level: null,
      )).future);

      expect(agg!['group'], {'key': 'tag:Category'});
    });

    test('P7.6b spendByDayProvider — group key date', () async {
      final mock = _MockGraphQLClient();
      Map<String, dynamic>? agg;
      var call = 0;
      when(() => mock.query(any())).thenAnswer((inv) async {
        final o = inv.positionalArguments[0] as QueryOptions;
        call++;
        if (o.variables.containsKey('input')) {
          return _qr({'getKgqlModelType': [_expenseMtJson()]});
        }
        if (o.variables.containsKey('filterkgql')) {
          agg = o.variables['aggregate'] as Map<String, dynamic>?;
          return _qr({'getKgqlAggregate': '{}'});
        }
        throw StateError('unexpected call $call');
      });

      final container = ProviderContainer(
        overrides: [graphqlClientProvider.overrideWithValue(mock)],
      );
      addTearDown(container.dispose);

      await container.read(spendByDayProvider.future);

      expect(agg!['group'], {'key': 'date'});
    });

    test('P7.7 spendByRelationProvider — group key Company.name', () async {
      final mock = _MockGraphQLClient();
      Map<String, dynamic>? agg;
      var call = 0;
      when(() => mock.query(any())).thenAnswer((inv) async {
        final o = inv.positionalArguments[0] as QueryOptions;
        call++;
        if (o.variables.containsKey('input')) {
          return _qr({'getKgqlModelType': [_expenseMtJson()]});
        }
        if (o.variables.containsKey('filterkgql')) {
          agg = o.variables['aggregate'] as Map<String, dynamic>?;
          return _qr({'getKgqlAggregate': '{}'});
        }
        throw StateError('unexpected call $call');
      });

      final container = ProviderContainer(
        overrides: [graphqlClientProvider.overrideWithValue(mock)],
      );
      addTearDown(container.dispose);

      await container.read(spendByRelationProvider('Company').future);

      expect(agg!['group'], {'key': 'Company.name'});
    });

    test('P7.8 relatedModelsProvider — filter model_type Company', () async {
      final mock = _MockGraphQLClient();
      QueryOptions? captured;
      when(() => mock.query(any())).thenAnswer((inv) async {
        captured = inv.positionalArguments[0] as QueryOptions;
        return _qr({
          'getKgqlModels': [
            {'id': 1, 'name': 'Acme', 'model_type_id': 2},
          ],
        });
      });

      final container = ProviderContainer(
        overrides: [graphqlClientProvider.overrideWithValue(mock)],
      );
      addTearDown(container.dispose);

      final list = await container.read(relatedModelsProvider('Company').future);
      expect(list.length, 1);
      expect((captured!.variables['filter'] as Map)['model_type'], 'Company');
    });

    test('P7.9 invalidate expenseSchemaProvider — struct recomputes', () async {
      final mock = _MockGraphQLClient();
      var mtCalls = 0;
      when(() => mock.query(any())).thenAnswer((inv) async {
        final o = inv.positionalArguments[0] as QueryOptions;
        if (!o.variables.containsKey('input')) {
          throw StateError('expected only model type queries');
        }
        mtCalls++;
        final json = _expenseMtJson(extraAttr: mtCalls >= 2);
        return _qr({'getKgqlModelType': [json]});
      });

      final container = ProviderContainer(
        overrides: [graphqlClientProvider.overrideWithValue(mock)],
      );
      addTearDown(container.dispose);

      await container.read(expenseSchemaProvider.future);
      final s1 = container.read(expenseStructProvider);
      expect(s1.containsKey('note'), false);

      container.invalidate(expenseSchemaProvider);
      await container.read(expenseSchemaProvider.future);
      final s2 = container.read(expenseStructProvider);

      expect(s2['note'], true);
      expect(s1, isNot(equals(s2)));
    });

    test('P7.10 expenseTimelineLinksProvider — parses links from modelById', () async {
      final mock = _MockGraphQLClient();
      when(() => mock.query(any())).thenAnswer((_) async {
        return _qr({
          'modelById': {
            'id': 100,
            'modelTimelineEventLinksByModelId': {
              'nodes': [
                {
                  'id': 55,
                  'timelineEventByEventTimeAndEventId': {
                    'time': '2026-04-01T12:00:00.000Z',
                    'id': 'evt-99',
                    'eventType': 'teller_transaction',
                    'payload': {'amount': '12.00', 'description': 'Test'},
                  },
                },
              ],
            },
          },
        });
      });

      final container = ProviderContainer(
        overrides: [graphqlClientProvider.overrideWithValue(mock)],
      );
      addTearDown(container.dispose);

      final links = await container.read(expenseTimelineLinksProvider(100).future);
      expect(links.length, 1);
      expect(links.single.linkId, '55');
      expect(links.single.eventId, 'evt-99');
      expect(links.single.payload['amount'], '12.00');
    });
  });
}
