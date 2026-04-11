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
  final double? minAmount;
  final double? maxAmount;

  const ExpenseFilter({this.tagFilters, this.minAmount, this.maxAmount});

  bool get isEmpty =>
      (tagFilters == null || tagFilters!.isEmpty) &&
      minAmount == null &&
      maxAmount == null;

  int get activeCount {
    int c = 0;
    if (tagFilters != null && tagFilters!.isNotEmpty) c += tagFilters!.length;
    if (minAmount != null) c++;
    if (maxAmount != null) c++;
    return c;
  }
}

/// Sort options for expense list.
enum ExpenseSortMode {
  dateDesc('Date (newest first)'),
  dateAsc('Date (oldest first)'),
  amountDesc('Amount (high to low)'),
  amountAsc('Amount (low to high)');

  const ExpenseSortMode(this.label);
  final String label;
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

/// Sort state for expense list.
class ExpenseListSortNotifier extends Notifier<ExpenseSortMode> {
  @override
  ExpenseSortMode build() => ExpenseSortMode.dateDesc;

  void setSort(ExpenseSortMode value) => state = value;
}

final expenseListSortProvider =
    NotifierProvider<ExpenseListSortNotifier, ExpenseSortMode>(ExpenseListSortNotifier.new);

/// Optional date range for expense list.
class ExpenseListDateRangeNotifier extends Notifier<DateTimeRange?> {
  @override
  DateTimeRange? build() => null;

  void setRange(DateTimeRange? value) => state = value;
}

final expenseListDateRangeProvider =
    NotifierProvider<ExpenseListDateRangeNotifier, DateTimeRange?>(ExpenseListDateRangeNotifier.new);

/// Same as [expenseListProvider] but uses [expenseListFilterProvider],
/// [expenseListSortProvider], and [expenseListDateRangeProvider].
final expenseListForUiProvider = FutureProvider<List<Model>>((ref) async {
  final filter = ref.watch(expenseListFilterProvider);
  final dateRange = ref.watch(expenseListDateRangeProvider);
  final sortMode = ref.watch(expenseListSortProvider);

  final list = await ref.watch(expenseListProvider((filter: filter, dateRange: dateRange)).future);

  // Client-side amount filtering (attribute-based, not available server-side).
  final schema = await ref.watch(expenseSchemaProvider.future);
  final amountKey = primaryNumberAttributeKey(schema);
  var filtered = list;
  if (amountKey != null && filter != null) {
    if (filter.minAmount != null || filter.maxAmount != null) {
      filtered = filtered.where((m) {
        final raw = m.attributes?[amountKey];
        if (raw == null) return false;
        final v = (raw is num) ? raw.toDouble() : double.tryParse('$raw');
        if (v == null) return false;
        if (filter.minAmount != null && v < filter.minAmount!) return false;
        if (filter.maxAmount != null && v > filter.maxAmount!) return false;
        return true;
      }).toList();
    }
  }

  // Sort
  final sorted = [...filtered];
  switch (sortMode) {
    case ExpenseSortMode.dateDesc:
      sorted.sort((a, b) => (b.createdAt ?? '').compareTo(a.createdAt ?? ''));
    case ExpenseSortMode.dateAsc:
      sorted.sort((a, b) => (a.createdAt ?? '').compareTo(b.createdAt ?? ''));
    case ExpenseSortMode.amountDesc:
    case ExpenseSortMode.amountAsc:
      if (amountKey != null) {
        sorted.sort((a, b) {
          final va = _numAttr(a, amountKey);
          final vb = _numAttr(b, amountKey);
          return sortMode == ExpenseSortMode.amountDesc
              ? vb.compareTo(va)
              : va.compareTo(vb);
        });
      }
  }
  return sorted;
});

double _numAttr(Model m, String key) {
  final raw = m.attributes?[key];
  if (raw is num) return raw.toDouble();
  return double.tryParse('$raw') ?? 0;
}

/// Expense list summary that respects the date range.
final expenseListSummaryProvider = FutureProvider<ExpenseSummary>((ref) async {
  final client = ref.watch(graphqlClientProvider);
  final schema = await ref.watch(expenseSchemaProvider.future);
  final key = primaryNumberAttributeKey(schema);
  final dateRange = ref.watch(expenseListDateRangeProvider);
  final tagFilter = ref.watch(expenseListFilterProvider);

  final filterMap = <String, dynamic>{'model_type': kExpenseModelTypeName};
  final filters = <Map<String, dynamic>>[];
  if (dateRange != null) {
    filters.add({'key': 'created_at', 'op': '>=', 'value': dateRange.start.toIso8601String()});
    filters.add({'key': 'created_at', 'op': '<=', 'value': dateRange.end.toIso8601String()});
  }
  if (filters.isNotEmpty) filterMap['filters'] = filters;
  if (tagFilter?.tagFilters != null && tagFilter!.tagFilters!.isNotEmpty) {
    filterMap['tag_filters'] = tagFilter.tagFilters;
  }

  final countMap = await getKgqlAggregate(
    client,
    filterMap,
    {'metric': 'count', 'key': null, 'group': null},
  );
  final count = (countMap['aggregated_value'] as num?)?.toInt() ?? 0;

  num? sum;
  if (key != null) {
    final sumMap = await getKgqlAggregate(
      client,
      filterMap,
      {'metric': 'sum', 'key': key, 'group': null},
    );
    sum = sumMap['aggregated_value'] as num?;
  }

  return ExpenseSummary(count: count, sumTotal: sum);
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
    FutureProvider.family<List<Model>, ({ExpenseFilter? filter, DateTimeRange? dateRange})>((ref, params) async {
  final schema = await ref.watch(expenseSchemaProvider.future);
  final struct = buildExpenseStruct(schema);
  final client = ref.watch(graphqlClientProvider);

  final filterMap = <String, dynamic>{
    'model_type': kExpenseModelTypeName,
    if (params.filter?.tagFilters != null && params.filter!.tagFilters!.isNotEmpty)
      'tag_filters': params.filter!.tagFilters,
  };

  if (params.dateRange != null) {
    final filters = <Map<String, dynamic>>[
      {'key': 'created_at', 'op': '>=', 'value': params.dateRange!.start.toIso8601String()},
      {'key': 'created_at', 'op': '<=', 'value': params.dateRange!.end.toIso8601String()},
    ];
    filterMap['filters'] = filters;
  }

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

/// Sum grouped by tag system with optional drill-down.
/// [parentNode]: if set, filter to this node's descendants before grouping.
/// [level]: group at this hierarchy level (1 = root, null = leaf).
final spendByTagSystemProvider =
    FutureProvider.family<Map<String, dynamic>, ({String systemName, String? parentNode, int? level})>((ref, params) async {
  final client = ref.watch(graphqlClientProvider);
  final schema = await ref.watch(expenseSchemaProvider.future);
  final key = primaryNumberAttributeKey(schema);
  if (key == null) return {};

  final filter = Map<String, dynamic>.from(_dashboardFilterKgql(ref));
  if (params.parentNode != null) {
    final existing = filter['tag_filters'] as List? ?? [];
    filter['tag_filters'] = [
      ...existing,
      {'system': params.systemName, 'node': params.parentNode, 'include_descendants': true},
    ];
  }

  final group = <String, dynamic>{'key': 'tag:${params.systemName}'};
  if (params.level != null) group['level'] = params.level;

  return getKgqlAggregate(client, filter, {
    'metric': 'sum',
    'key': key,
    'group': group,
  });
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
