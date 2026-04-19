import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:nx_db/kgql.dart';

import 'package:nx_expense/data/expense/expense_attr_keys.dart';
import 'package:nx_expense/data/teller/expense_timeline_api.dart';
import 'package:nx_expense/data/expense/expense_mapper.dart';
import 'package:nx_expense/data/expense/expense_set_model_request.dart';
import 'package:nx_expense/data/expense/expense_struct.dart';
import 'package:nx_expense/domain/expense/expense.dart';
import 'package:nx_expense/domain/expense/expense_filter.dart';
import 'package:nx_expense/domain/expense/expense_repository.dart';
import 'package:nx_expense/domain/expense/expense_summary.dart';
import 'package:nx_expense/domain/expense/expense_upsert.dart';
import 'package:nx_expense/domain/expense/model_names.dart';
String _dateOnlyYmd(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

class KgqlExpenseRepository implements ExpenseRepository {
  KgqlExpenseRepository({
    required GraphQLClient client,
    required Future<ModelType> Function() loadExpenseSchema,
  })  : _client = client,
        _loadExpenseSchema = loadExpenseSchema;

  final GraphQLClient _client;
  final Future<ModelType> Function() _loadExpenseSchema;

  @override
  Future<List<Expense>> list({
    ExpenseFilter? filter,
    required DateTime rangeStart,
    required DateTime rangeEnd,
  }) async {
    final schema = await _loadExpenseSchema();
    final struct = buildExpenseStruct(schema);
    final filterMap = <String, dynamic>{
      'model_type': kExpenseModelTypeName,
      if (filter?.tagFilters != null && filter!.tagFilters!.isNotEmpty)
        'tag_filters': filter.tagFilters,
      'filters': [
        {
          'key': 'date',
          'op': '>=',
          'value': _dateOnlyYmd(rangeStart),
        },
        {
          'key': 'date',
          'op': '<=',
          'value': _dateOnlyYmd(rangeEnd),
        },
      ],
    };
    final rows = await fetchKgqlModels(_client, filter: filterMap, struct: struct);
    return rows.map(expenseFromModel).toList();
  }

  @override
  Future<Expense?> getById(int id) async {
    final schema = await _loadExpenseSchema();
    final struct = buildExpenseStruct(schema);
    final m = await fetchKgqlModelById(
      _client,
      modelTypeName: kExpenseModelTypeName,
      id: id,
      struct: struct,
    );
    return m == null ? null : expenseFromModel(m);
  }

  @override
  Future<int> upsert(ExpenseUpsert payload) async {
    final req = buildExpenseSetModelRequest(payload);
    return setKgqlModel(_client, req);
  }

  @override
  Future<void> deleteById(int id) async {
    await setKgqlModel(_client, SetModelRequest(id: id, delete: true));
  }

  @override
  Future<int> createMinimalExpense({
    required String name,
    required num amount,
  }) async {
    final schema = await _loadExpenseSchema();
    final numberKey = schema.attributes
        ?.where((a) => a.valueType == 'number' && (a.key ?? '').isNotEmpty)
        .map((a) => a.key!)
        .firstOrNull;
    final dateKey = schema.attributes
        ?.where((a) => (a.key ?? '').toLowerCase() == 'date')
        .map((a) => a.key!)
        .firstOrNull;
    final today = _dateOnlyYmd(DateTime.now());
    final normalizedAmount = -amount.abs();
    final attrs = <String, dynamic>{
      kExpenseIgnoreAttributeKey: false,
      if (numberKey != null) numberKey: normalizedAmount,
      if (dateKey != null) dateKey: today,
    };
    return upsert(
      ExpenseUpsert(
        id: null,
        name: name,
        description: null,
        attributes: attrs,
        tags: const {},
        relationsByType: const {},
        relationCreatesByType: const {},
        relationEdgeIdsByType: const {},
        snapshotLinkIdsByType: const {},
        snapshotCreatesByType: const {},
      ),
    );
  }

  @override
  Future<void> linkExpenseToTellerTimeline({
    required int expenseId,
    required String tellerEventId,
    required DateTime tellerEventTime,
  }) async {
    await linkModelToTimelineEvent(
      _client,
      modelId: expenseId,
      eventTime: tellerEventTime,
      eventId: tellerEventId,
    );
  }

  Map<String, dynamic> _dashboardFilter({
    required DateTime rangeStart,
    required DateTime rangeEnd,
  }) {
    return <String, dynamic>{
      'model_type': kExpenseModelTypeName,
      'filters': [
        {'key': 'date', 'op': '>=', 'value': _dateOnlyYmd(rangeStart)},
        {'key': 'date', 'op': '<=', 'value': _dateOnlyYmd(rangeEnd)},
        {'key': kExpenseIgnoreAttributeKey, 'op': '!=', 'value': true},
      ],
    };
  }

  @override
  Future<ExpenseSummary> globalSummary() async {
    final schema = await _loadExpenseSchema();
    final key = schema.attributes
            ?.where((a) => a.valueType == 'number' && (a.key ?? '').isNotEmpty)
            .map((a) => a.key!)
            .firstOrNull;

    final countMap = await getKgqlAggregate(
      _client,
      {'model_type': kExpenseModelTypeName},
      {'metric': 'count', 'key': null, 'group': null},
    );
    final count = (countMap['aggregated_value'] as num?)?.toInt() ?? 0;

    num? sum;
    if (key != null) {
      final sumMap = await getKgqlAggregate(
        _client,
        {'model_type': kExpenseModelTypeName},
        {'metric': 'sum', 'key': key, 'group': null},
      );
      sum = sumMap['aggregated_value'] as num?;
    }

    return ExpenseSummary(count: count, sumTotal: sum);
  }

  @override
  Future<ExpenseSummary> dashboardSummary({
    required DateTime rangeStart,
    required DateTime rangeEnd,
  }) async {
    final schema = await _loadExpenseSchema();
    final key = schema.attributes
        ?.where((a) => a.valueType == 'number' && (a.key ?? '').isNotEmpty)
        .map((a) => a.key!)
        .firstOrNull;
    final filterKgql = _dashboardFilter(
      rangeStart: rangeStart,
      rangeEnd: rangeEnd,
    );

    final countMap = await getKgqlAggregate(_client, filterKgql, {
      'metric': 'count',
      'key': null,
      'group': null,
    });
    final count = (countMap['aggregated_value'] as num?)?.toInt() ?? 0;

    num? sum;
    if (key != null) {
      final sumMap = await getKgqlAggregate(_client, filterKgql, {
        'metric': 'sum',
        'key': key,
        'group': null,
      });
      sum = sumMap['aggregated_value'] as num?;
    }

    return ExpenseSummary(count: count, sumTotal: sum);
  }

  @override
  Future<Map<String, dynamic>> spendByDay({
    required DateTime rangeStart,
    required DateTime rangeEnd,
  }) async {
    final schema = await _loadExpenseSchema();
    final key = schema.attributes
        ?.where((a) => a.valueType == 'number' && (a.key ?? '').isNotEmpty)
        .map((a) => a.key!)
        .firstOrNull;
    if (key == null) return {};
    return getKgqlAggregate(
      _client,
      _dashboardFilter(rangeStart: rangeStart, rangeEnd: rangeEnd),
      {
        'metric': 'sum',
        'key': key,
        'group': {'key': 'date'},
      },
    );
  }

  @override
  Future<Map<String, dynamic>> spendByTagSystem({
    required DateTime rangeStart,
    required DateTime rangeEnd,
    required String systemName,
    String? parentNode,
    int? level,
  }) async {
    final schema = await _loadExpenseSchema();
    final key = schema.attributes
        ?.where((a) => a.valueType == 'number' && (a.key ?? '').isNotEmpty)
        .map((a) => a.key!)
        .firstOrNull;
    if (key == null) return {};

    final filter = Map<String, dynamic>.from(
      _dashboardFilter(rangeStart: rangeStart, rangeEnd: rangeEnd),
    );
    if (parentNode != null) {
      final existing = filter['tag_filters'] as List? ?? [];
      filter['tag_filters'] = [
        ...existing,
        {
          'system': systemName,
          'node': parentNode,
          'include_descendants': true,
        },
      ];
    }

    final group = <String, dynamic>{'key': 'tag:$systemName'};
    if (level != null) group['level'] = level;

    return getKgqlAggregate(_client, filter, {
      'metric': 'sum',
      'key': key,
      'group': group,
    });
  }

  @override
  Future<Map<String, dynamic>> spendByRelation({
    required DateTime rangeStart,
    required DateTime rangeEnd,
    required String targetTypeName,
  }) async {
    final schema = await _loadExpenseSchema();
    final key = schema.attributes
        ?.where((a) => a.valueType == 'number' && (a.key ?? '').isNotEmpty)
        .map((a) => a.key!)
        .firstOrNull;
    if (key == null) return {};

    return getKgqlAggregate(
      _client,
      _dashboardFilter(rangeStart: rangeStart, rangeEnd: rangeEnd),
      {
        'metric': 'sum',
        'key': key,
        'group': {'key': '$targetTypeName.name'},
      },
    );
  }
}

extension _FirstOrNull<E> on Iterable<E> {
  E? get firstOrNull {
    final it = iterator;
    if (!it.moveNext()) return null;
    return it.current;
  }
}
