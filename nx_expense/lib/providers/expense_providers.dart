import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:nx_db/nx_db.dart';

import '../expense_schema.dart';

const String _getKgqlModelsQuery = '''
query GetKgqlModels(\$filter: JSON!, \$struct: JSON!) {
  getKgqlModels(filter: \$filter, struct: \$struct)
}
''';

const String _getExpenseModelTypeQuery = '''
query GetExpenseModelType(\$input: JSON!) {
  getKgqlModelType(input: \$input)
}
''';

/// Cached Expense model type with attributes, relations, and tag systems.
final expenseSchemaProvider = FutureProvider<ModelType>((ref) async {
  final client = ref.watch(graphqlClientProvider);
  final result = await client.query(
    QueryOptions(
      document: gql(_getExpenseModelTypeQuery),
      variables: {
        'input': {
          'model_types': [kExpenseModelTypeName],
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
            'tag_systems': true,
          },
        },
      },
      fetchPolicy: FetchPolicy.networkOnly,
    ),
  );

  if (result.hasException) {
    throw result.exception!;
  }

  final raw = result.data?['getKgqlModelType'];
  if (raw == null) {
    throw StateError('getKgqlModelType returned null');
  }

  final jsonArray = raw is String
      ? json.decode(raw) as List<dynamic>
      : raw as List<dynamic>;

  if (jsonArray.isEmpty) {
    throw StateError('Model type "$kExpenseModelTypeName" not found');
  }

  return ModelType.fromJson(
    jsonArray.first as Map<String, dynamic>,
    recursive: true,
  );
});

/// `struct` JSON derived from [expenseSchemaProvider] for list/detail queries.
final expenseStructProvider = Provider<Map<String, dynamic>>((ref) {
  final async = ref.watch(expenseSchemaProvider);
  return async.maybeWhen(
    data: buildExpenseStruct,
    orElse: () => <String, dynamic>{},
  );
});

/// Optional filters for expense list (e.g. tag filters).
@immutable
class ExpenseFilter {
  final List<Map<String, dynamic>>? tagFilters;

  const ExpenseFilter({this.tagFilters});
}

List<Model> _parseModels(dynamic jsonResult) {
  if (jsonResult == null) return [];
  final jsonArray = jsonResult is String
      ? json.decode(jsonResult) as List<dynamic>
      : jsonResult as List<dynamic>;
  return jsonArray.map((e) {
    if (e is Map<String, dynamic>) {
      return Model.fromJson(e);
    }
    return null;
  }).whereType<Model>().toList();
}

/// UI filter state (tag chips). `null` = show all expenses.
class ExpenseListFilterNotifier extends Notifier<ExpenseFilter?> {
  @override
  ExpenseFilter? build() => null;

  void setFilter(ExpenseFilter? value) => state = value;
}

final expenseListFilterProvider =
    NotifierProvider<ExpenseListFilterNotifier, ExpenseFilter?>(ExpenseListFilterNotifier.new);

/// Same as [expenseListProvider] but uses [expenseListFilterProvider] and sorts by `created_at` desc.
final expenseListForUiProvider = FutureProvider<List<Model>>((ref) async {
  final filter = ref.watch(expenseListFilterProvider);
  final list = await ref.watch(expenseListProvider(filter).future);
  return sortModelsByCreatedAtDesc(list);
});

/// Optional date range for dashboard aggregates only.
class DashboardDateRangeNotifier extends Notifier<DateTimeRange?> {
  @override
  DateTimeRange? build() => null;

  void setRange(DateTimeRange? value) => state = value;
}

final dashboardDateRangeProvider =
    NotifierProvider<DashboardDateRangeNotifier, DateTimeRange?>(DashboardDateRangeNotifier.new);

Map<String, dynamic> _dashboardFilterKgql(Ref ref) {
  final range = ref.watch(dashboardDateRangeProvider);
  final base = <String, dynamic>{'model_type': kExpenseModelTypeName};
  if (range != null) {
    base['filters'] = [
      {'key': 'created_at', 'op': '>=', 'value': range.start.toIso8601String()},
      {'key': 'created_at', 'op': '<=', 'value': range.end.toIso8601String()},
    ];
  }
  return base;
}

/// Lists Expense models using the dynamic struct from the schema.
final expenseListProvider =
    FutureProvider.family<List<Model>, ExpenseFilter?>((ref, filter) async {
  final schema = await ref.watch(expenseSchemaProvider.future);
  final struct = buildExpenseStruct(schema);
  final client = ref.watch(graphqlClientProvider);

  final filterMap = <String, dynamic>{
    'model_type': kExpenseModelTypeName,
    if (filter?.tagFilters != null && filter!.tagFilters!.isNotEmpty)
      'tag_filters': filter.tagFilters,
  };

  final result = await client.query(
    QueryOptions(
      document: gql(_getKgqlModelsQuery),
      variables: {
        'filter': filterMap,
        'struct': struct,
      },
      fetchPolicy: FetchPolicy.networkOnly,
    ),
  );

  if (result.hasException) {
    throw result.exception!;
  }

  return _parseModels(result.data?['getKgqlModels']);
});

/// Single expense by numeric id.
final expenseDetailProvider = FutureProvider.family<Model?, int>((ref, id) async {
  final schema = await ref.watch(expenseSchemaProvider.future);
  final struct = buildExpenseStruct(schema);
  final client = ref.watch(graphqlClientProvider);

  final result = await client.query(
    QueryOptions(
      document: gql(_getKgqlModelsQuery),
      variables: {
        'filter': {
          'filters': [
            {'key': 'id', 'op': '=', 'value': id.toString()},
          ],
        },
        'struct': struct,
      },
      fetchPolicy: FetchPolicy.networkOnly,
    ),
  );

  if (result.hasException) {
    throw result.exception!;
  }

  final list = _parseModels(result.data?['getKgqlModels']);
  if (list.isEmpty) return null;
  return list.first;
});

@immutable
class ExpenseSummary {
  final int count;
  final num? sumTotal;

  const ExpenseSummary({required this.count, this.sumTotal});
}

/// Count + optional sum on the first number attribute (global, no date filter).
final expenseSummaryProvider = FutureProvider<ExpenseSummary>((ref) async {
  final client = ref.watch(graphqlClientProvider);
  final schema = await ref.watch(expenseSchemaProvider.future);
  final key = primaryNumberAttributeKey(schema);

  final countMap = await getKgqlAggregate(
    client,
    {'model_type': kExpenseModelTypeName},
    {'metric': 'count', 'key': null, 'group': null},
  );
  final count = (countMap['aggregated_value'] as num?)?.toInt() ?? 0;

  num? sum;
  if (key != null) {
    final sumMap = await getKgqlAggregate(
      client,
      {'model_type': kExpenseModelTypeName},
      {'metric': 'sum', 'key': key, 'group': null},
    );
    sum = sumMap['aggregated_value'] as num?;
  }

  return ExpenseSummary(count: count, sumTotal: sum);
});

/// Dashboard summary — respects [dashboardDateRangeProvider].
final dashboardExpenseSummaryProvider = FutureProvider<ExpenseSummary>((ref) async {
  final client = ref.watch(graphqlClientProvider);
  final schema = await ref.watch(expenseSchemaProvider.future);
  final key = primaryNumberAttributeKey(schema);
  final filterKgql = _dashboardFilterKgql(ref);

  final countMap = await getKgqlAggregate(
    client,
    filterKgql,
    {'metric': 'count', 'key': null, 'group': null},
  );
  final count = (countMap['aggregated_value'] as num?)?.toInt() ?? 0;

  num? sum;
  if (key != null) {
    final sumMap = await getKgqlAggregate(
      client,
      filterKgql,
      {'metric': 'sum', 'key': key, 'group': null},
    );
    sum = sumMap['aggregated_value'] as num?;
  }

  return ExpenseSummary(count: count, sumTotal: sum);
});

/// Sum grouped by calendar day (`created_at` window). Uses dashboard date range when set.
final spendByDayProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final client = ref.watch(graphqlClientProvider);
  final schema = await ref.watch(expenseSchemaProvider.future);
  final key = primaryNumberAttributeKey(schema);
  if (key == null) return {};

  return getKgqlAggregate(
    client,
    _dashboardFilterKgql(ref),
    {
      'metric': 'sum',
      'key': key,
      'group': {'key': 'created_at', 'window': 'day'},
    },
  );
});

/// Sum grouped by tag system (group key `tag:<systemName>`).
final spendByTagSystemProvider =
    FutureProvider.family<Map<String, dynamic>, String>((ref, systemName) async {
  final client = ref.watch(graphqlClientProvider);
  final schema = await ref.watch(expenseSchemaProvider.future);
  final key = primaryNumberAttributeKey(schema);
  if (key == null) return {};

  return getKgqlAggregate(
    client,
    _dashboardFilterKgql(ref),
    {
      'metric': 'sum',
      'key': key,
      'group': {'key': 'tag:$systemName'},
    },
  );
});

/// Sum grouped by related model name for a relation target type.
final spendByRelationProvider =
    FutureProvider.family<Map<String, dynamic>, String>((ref, targetTypeName) async {
  final client = ref.watch(graphqlClientProvider);
  final schema = await ref.watch(expenseSchemaProvider.future);
  final key = primaryNumberAttributeKey(schema);
  if (key == null) return {};

  return getKgqlAggregate(
    client,
    _dashboardFilterKgql(ref),
    {
      'metric': 'sum',
      'key': key,
      'group': {'key': '$targetTypeName.name'},
    },
  );
});

/// All models of a given type (for relation pickers).
final relatedModelsProvider =
    FutureProvider.family<List<Model>, String>((ref, modelTypeName) async {
  final client = ref.watch(graphqlClientProvider);

  final result = await client.query(
    QueryOptions(
      document: gql(_getKgqlModelsQuery),
      variables: {
        'filter': {'model_type': modelTypeName},
        'struct': {
          'id': true,
          'name': true,
          'description': true,
          'model_type_id': true,
          'created_at': true,
          'updated_at': true,
        },
      },
      fetchPolicy: FetchPolicy.networkOnly,
    ),
  );

  if (result.hasException) {
    throw result.exception!;
  }

  return _parseModels(result.data?['getKgqlModels']);
});
