import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nx_db/nx_db.dart';

import '../data/expense_timeline_api.dart';
import '../util/expense_schema.dart';

/// Calendar day as `YYYY-MM-DD` for KGQL filters on Expense/Transfer `date` attributes.
String _dateOnlyYmd(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// Cached Expense model type with attributes, relations, and tag systems.
final expenseSchemaProvider = modelTypeByNameProvider(kExpenseModelTypeName);

/// Cached Transfer model type (attributes, relations).
final transferSchemaProvider = modelTypeByNameProvider(kTransferModelTypeName);

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

  /// Relation filters: relation type name → set of model IDs to include.
  final Map<String, Set<int>>? relationFilters;

  /// Display names for chips: relation type → model id → name (optional; falls back to `#id`).
  final Map<String, Map<int, String>>? relationFilterLabels;

  const ExpenseFilter({
    this.tagFilters,
    this.minAmount,
    this.maxAmount,
    this.relationFilters,
    this.relationFilterLabels,
  });

  bool get isEmpty =>
      (tagFilters == null || tagFilters!.isEmpty) &&
      minAmount == null &&
      maxAmount == null &&
      (relationFilters == null ||
          relationFilters!.values.every((s) => s.isEmpty));

  int get activeCount {
    int c = 0;
    if (tagFilters != null && tagFilters!.isNotEmpty) c += tagFilters!.length;
    if (minAmount != null) c++;
    if (maxAmount != null) c++;
    if (relationFilters != null) {
      for (final ids in relationFilters!.values) {
        c += ids.length;
      }
    }
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

/// UI filter state (tag chips). `null` = show all expenses.
class ExpenseListFilterNotifier extends Notifier<ExpenseFilter?> {
  @override
  ExpenseFilter? build() => null;

  void setFilter(ExpenseFilter? value) => state = value;
}

final expenseListFilterProvider =
    NotifierProvider<ExpenseListFilterNotifier, ExpenseFilter?>(
      ExpenseListFilterNotifier.new,
    );

/// Sort state for expense list.
class ExpenseListSortNotifier extends Notifier<ExpenseSortMode> {
  @override
  ExpenseSortMode build() => ExpenseSortMode.dateAsc;

  void setSort(ExpenseSortMode value) => state = value;
}

final expenseListSortProvider =
    NotifierProvider<ExpenseListSortNotifier, ExpenseSortMode>(
      ExpenseListSortNotifier.new,
    );

DateTimeRange _calendarMonthRange(DateTime forDay) {
  final start = DateTime(forDay.year, forDay.month);
  final end = DateTime(
    forDay.year,
    forDay.month + 1,
  ).subtract(const Duration(days: 1));
  return DateTimeRange(start: start, end: end);
}

/// Shared date window for expense list, dashboard aggregates, and charts.
class ExpenseDateRangeNotifier extends Notifier<DateTimeRange> {
  @override
  DateTimeRange build() => _calendarMonthRange(DateTime.now());

  void setRange(DateTimeRange value) => state = value;
}

final expenseDateRangeProvider =
    NotifierProvider<ExpenseDateRangeNotifier, DateTimeRange>(
      ExpenseDateRangeNotifier.new,
    );

/// Default range for tag/relation deep-linked lists: Jan 1, 2025 through end of
/// today (local), so opening that screen shows a wide window without changing
/// the main tab’s month.
DateTimeRange kScopedFilteredExpenseDateRange() {
  final now = DateTime.now();
  return DateTimeRange(
    start: DateTime(2025, 1, 1),
    end: DateTime(now.year, now.month, now.day, 23, 59, 59, 999),
  );
}

class ScopedFilteredExpenseDateRangeNotifier extends ExpenseDateRangeNotifier {
  @override
  DateTimeRange build() => kScopedFilteredExpenseDateRange();
}

/// Same as [expenseListProvider] but uses [expenseListFilterProvider],
/// [expenseListSortProvider], and [expenseDateRangeProvider].
///
/// Exposed so nested [ProviderScope] overrides can reuse the same logic while
/// resolving [expenseListFilterProvider] (and downstream providers) from the
/// scoped container.
Future<List<Model>> buildExpenseListForUi(Ref ref) async {
  final filter = ref.watch(expenseListFilterProvider);
  final dateRange = ref.watch(expenseDateRangeProvider);
  final sortMode = ref.watch(expenseListSortProvider);

  final list = await ref.watch(
    expenseListProvider((filter: filter, dateRange: dateRange)).future,
  );

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

  // Client-side relation filtering.
  if (filter != null &&
      filter.relationFilters != null &&
      filter.relationFilters!.isNotEmpty) {
    filtered = filtered.where((m) {
      for (final entry in filter.relationFilters!.entries) {
        final ids = entry.value;
        if (ids.isEmpty) continue;
        final rels = m.relations?[entry.key];
        if (rels == null || rels.isEmpty) return false;
        final modelIds = rels.map((r) => r.id).toSet();
        if (!ids.any((id) => modelIds.contains(id))) return false;
      }
      return true;
    }).toList();
  }

  // Sort
  final sorted = [...filtered];
  switch (sortMode) {
    case ExpenseSortMode.dateDesc:
      sorted.sort((a, b) => modelDateSortKey(b).compareTo(modelDateSortKey(a)));
    case ExpenseSortMode.dateAsc:
      sorted.sort((a, b) => modelDateSortKey(a).compareTo(modelDateSortKey(b)));
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
}

final expenseListForUiProvider = FutureProvider<List<Model>>(
  (ref) => buildExpenseListForUi(ref),
);

double _numAttr(Model m, String key) {
  final raw = m.attributes?[key];
  if (raw is num) return raw.toDouble();
  return double.tryParse('$raw') ?? 0;
}

// ── Search (client-side name + description on [expenseListForUiProvider]) ─────

class ExpenseListSearchQueryNotifier extends Notifier<String> {
  @override
  String build() => '';

  void setQuery(String q) => state = q;

  void clear() => state = '';
}

final expenseListSearchQueryProvider =
    NotifierProvider<ExpenseListSearchQueryNotifier, String>(
      ExpenseListSearchQueryNotifier.new,
    );

class ExpenseListSearchFieldExpandedNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void setExpanded(bool v) => state = v;
}

final expenseListSearchFieldExpandedProvider =
    NotifierProvider<ExpenseListSearchFieldExpandedNotifier, bool>(
      ExpenseListSearchFieldExpandedNotifier.new,
    );

/// Client-side filter: [query] must be lowercased trimmed substring match on
/// [Model.name] or [Model.description] only.
List<Model> filterExpenseModelsBySearch(List<Model> models, String query) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return models;

  bool matches(Model m) {
    if (m.name.toLowerCase().contains(q)) return true;
    final d = m.description;
    if (d != null && d.isNotEmpty && d.toLowerCase().contains(q)) return true;
    return false;
  }

  return models.where(matches).toList();
}

/// Same rows as the list UI: [expenseListForUiProvider] narrowed by search query.
Future<List<Model>> buildExpenseListDisplayed(Ref ref) async {
  final list = await ref.watch(expenseListForUiProvider.future);
  final q = ref.watch(expenseListSearchQueryProvider);
  return filterExpenseModelsBySearch(list, q);
}

final expenseListDisplayedProvider = FutureProvider<List<Model>>(
  (ref) => buildExpenseListDisplayed(ref),
);

/// Count + total for the **same rows** shown in the list (filters, sort, **and search**).
///
/// Rows with `ignore` true are excluded from both count and sum.
Future<ExpenseSummary> buildExpenseListSummary(Ref ref) async {
  final list = await ref.watch(expenseListDisplayedProvider.future);
  final schema = await ref.watch(expenseSchemaProvider.future);
  final key = primaryNumberAttributeKey(schema);

  final tallied = [
    for (final m in list)
      if (!expenseIgnoredForTotals(m)) m,
  ];

  num? sum;
  if (key != null) {
    sum = 0;
    for (final m in tallied) {
      sum = sum! + _numAttr(m, key);
    }
  }

  return ExpenseSummary(count: tallied.length, sumTotal: sum);
}

final expenseListSummaryProvider = FutureProvider<ExpenseSummary>(
  (ref) => buildExpenseListSummary(ref),
);

// ── Multi-select (rows = [expenseListDisplayedProvider]) ─────────────────────

class ExpenseListSelectedIdsNotifier extends Notifier<Set<int>> {
  @override
  Set<int> build() => {};

  void toggle(int id) {
    final next = {...state};
    if (next.contains(id)) {
      next.remove(id);
    } else {
      next.add(id);
    }
    state = next;
    debugPrint('[ExpenseListSelectedIds] toggle id=$id -> size=${next.length}');
  }

  void selectAll(Iterable<int> ids) => state = ids.toSet();

  void clear() => state = {};

  void pruneToVisible(Set<int> visible) {
    state = {
      for (final id in state)
        if (visible.contains(id)) id,
    };
  }
}

final expenseListSelectedIdsProvider =
    NotifierProvider<ExpenseListSelectedIdsNotifier, Set<int>>(
      ExpenseListSelectedIdsNotifier.new,
    );

class ExpenseListSelectionModeNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void setSelecting(bool v) {
    state = v;
    if (!v) {
      ref.read(expenseListSelectedIdsProvider.notifier).clear();
    }
  }
}

final expenseListSelectionModeProvider =
    NotifierProvider<ExpenseListSelectionModeNotifier, bool>(
      ExpenseListSelectionModeNotifier.new,
    );

/// When selection mode is on: count + sum of **selected** amounts among displayed rows.
ExpenseSummary? buildExpenseListSelectionSummary(Ref ref) {
  if (!ref.watch(expenseListSelectionModeProvider)) return null;
  final displayed = ref.watch(expenseListDisplayedProvider);
  final selected = ref.watch(expenseListSelectedIdsProvider);
  final list = displayed.maybeWhen(data: (l) => l, orElse: () => null);
  if (list == null) {
    return ExpenseSummary(count: selected.length, sumTotal: null);
  }
  final schema = ref
      .watch(expenseSchemaProvider)
      .maybeWhen(data: (s) => s, orElse: () => null);
  final key = schema != null ? primaryNumberAttributeKey(schema) : null;
  num? sum;
  if (key != null) {
    sum = 0;
    for (final m in list) {
      if (!selected.contains(m.id)) continue;
      if (expenseIgnoredForTotals(m)) continue;
      sum = sum! + _numAttr(m, key);
    }
  }
  return ExpenseSummary(count: selected.length, sumTotal: sum);
}

final expenseListSelectionSummaryProvider = Provider<ExpenseSummary?>(
  (ref) => buildExpenseListSelectionSummary(ref),
);

Map<String, dynamic> _dashboardFilterKgql(Ref ref) {
  final range = ref.watch(expenseDateRangeProvider);
  return <String, dynamic>{
    'model_type': kExpenseModelTypeName,
    'filters': [
      {'key': 'date', 'op': '>=', 'value': _dateOnlyYmd(range.start)},
      {'key': 'date', 'op': '<=', 'value': _dateOnlyYmd(range.end)},
      {'key': kExpenseIgnoreAttributeKey, 'op': '!=', 'value': true},
    ],
  };
}

/// Lists Expense models using the dynamic struct from the schema.
final expenseListProvider =
    FutureProvider.family<
      List<Model>,
      ({ExpenseFilter? filter, DateTimeRange dateRange})
    >((ref, params) async {
      final schema = await ref.watch(expenseSchemaProvider.future);
      final struct = buildExpenseStruct(schema);
      final client = ref.watch(graphqlClientProvider);

      final filterMap = <String, dynamic>{
        'model_type': kExpenseModelTypeName,
        if (params.filter?.tagFilters != null &&
            params.filter!.tagFilters!.isNotEmpty)
          'tag_filters': params.filter!.tagFilters,
        'filters': [
          {
            'key': 'date',
            'op': '>=',
            'value': _dateOnlyYmd(params.dateRange.start),
          },
          {
            'key': 'date',
            'op': '<=',
            'value': _dateOnlyYmd(params.dateRange.end),
          },
        ],
      };

      return fetchKgqlModels(client, filter: filterMap, struct: struct);
    });

/// List Transfer models for [expenseDateRangeProvider].
///
/// Filters by the **`date` attribute** (same field as list section headers), not
/// `created_at`, so transformed transfers appear in the month they belong to.
final transferListProvider = FutureProvider<List<Model>>((ref) async {
  final schema = await ref.watch(transferSchemaProvider.future);
  final struct = buildTransferStruct(schema);
  final client = ref.watch(graphqlClientProvider);
  final dateRange = ref.watch(expenseDateRangeProvider);

  return fetchKgqlModels(
    client,
    filter: {
      'model_type': kTransferModelTypeName,
      'filters': [
        {
          'key': 'date',
          'op': '>=',
          'value': _dateOnlyYmd(dateRange.start),
        },
        {
          'key': 'date',
          'op': '<=',
          'value': _dateOnlyYmd(dateRange.end),
        },
      ],
    },
    struct: struct,
  );
});

/// Transfers sorted by **`date` attribute** (newest first), then `created_at`.
final transferListForUiProvider = FutureProvider<List<Model>>((ref) async {
  final list = await ref.watch(transferListProvider.future);
  final sorted = [...list];
  sorted.sort((a, b) => modelDateSortKey(b).compareTo(modelDateSortKey(a)));
  return sorted;
});

/// Count + signed sum of transfer amounts for the list.
final transferListSummaryProvider = FutureProvider<ExpenseSummary>((ref) async {
  final list = await ref.watch(transferListForUiProvider.future);
  final schema = await ref.watch(transferSchemaProvider.future);
  final key = primaryNumberAttributeKey(schema);
  num? sum;
  if (key != null) {
    sum = 0;
    for (final m in list) {
      sum = sum! + _numAttr(m, key);
    }
  }
  return ExpenseSummary(count: list.length, sumTotal: sum);
});

/// Single expense by numeric id.
final expenseDetailProvider = FutureProvider.family<Model?, int>((
  ref,
  id,
) async {
  final schema = await ref.watch(expenseSchemaProvider.future);
  final struct = buildExpenseStruct(schema);
  final client = ref.watch(graphqlClientProvider);

  return fetchKgqlModelById(
    client,
    modelTypeName: kExpenseModelTypeName,
    id: id,
    struct: struct,
  );
});

/// Single transfer by numeric id (full struct for detail screen).
final transferDetailProvider = FutureProvider.family<Model?, int>((ref, id) async {
  final schema = await ref.watch(transferSchemaProvider.future);
  final struct = buildTransferStruct(schema);
  final client = ref.watch(graphqlClientProvider);

  return fetchKgqlModelById(
    client,
    modelTypeName: kTransferModelTypeName,
    id: id,
    struct: struct,
  );
});

/// `model_timeline_event_links` for an Expense model (e.g. Teller imports).
final expenseTimelineLinksProvider =
    FutureProvider.family<List<ExpenseTellerLink>, int>((ref, modelId) async {
  final client = ref.watch(graphqlClientProvider);
  return fetchExpenseTimelineLinks(client, modelId);
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

/// Dashboard summary — respects [expenseDateRangeProvider].
final dashboardExpenseSummaryProvider = FutureProvider<ExpenseSummary>((
  ref,
) async {
  final client = ref.watch(graphqlClientProvider);
  final schema = await ref.watch(expenseSchemaProvider.future);
  final key = primaryNumberAttributeKey(schema);
  final filterKgql = _dashboardFilterKgql(ref);

  final countMap = await getKgqlAggregate(client, filterKgql, {
    'metric': 'count',
    'key': null,
    'group': null,
  });
  final count = (countMap['aggregated_value'] as num?)?.toInt() ?? 0;

  num? sum;
  if (key != null) {
    final sumMap = await getKgqlAggregate(client, filterKgql, {
      'metric': 'sum',
      'key': key,
      'group': null,
    });
    sum = sumMap['aggregated_value'] as num?;
  }

  return ExpenseSummary(count: count, sumTotal: sum);
});

/// Sum grouped by Expense `date` attribute (per calendar day). Uses dashboard date range when set.
final spendByDayProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final client = ref.watch(graphqlClientProvider);
  final schema = await ref.watch(expenseSchemaProvider.future);
  final key = primaryNumberAttributeKey(schema);
  if (key == null) return {};

  return getKgqlAggregate(client, _dashboardFilterKgql(ref), {
    'metric': 'sum',
    'key': key,
    'group': {'key': 'date'},
  });
});

/// Sum grouped by tag system with optional drill-down.
/// [parentNode]: if set, filter to this node's descendants before grouping.
/// [level]: group at this hierarchy level (1 = root, null = leaf).
final spendByTagSystemProvider =
    FutureProvider.family<
      Map<String, dynamic>,
      ({String systemName, String? parentNode, int? level})
    >((ref, params) async {
      final client = ref.watch(graphqlClientProvider);
      final schema = await ref.watch(expenseSchemaProvider.future);
      final key = primaryNumberAttributeKey(schema);
      if (key == null) return {};

      final filter = Map<String, dynamic>.from(_dashboardFilterKgql(ref));
      if (params.parentNode != null) {
        final existing = filter['tag_filters'] as List? ?? [];
        filter['tag_filters'] = [
          ...existing,
          {
            'system': params.systemName,
            'node': params.parentNode,
            'include_descendants': true,
          },
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
    FutureProvider.family<Map<String, dynamic>, String>((
      ref,
      targetTypeName,
    ) async {
      final client = ref.watch(graphqlClientProvider);
      final schema = await ref.watch(expenseSchemaProvider.future);
      final key = primaryNumberAttributeKey(schema);
      if (key == null) return {};

      return getKgqlAggregate(client, _dashboardFilterKgql(ref), {
        'metric': 'sum',
        'key': key,
        'group': {'key': '$targetTypeName.name'},
      });
    });

/// All models of a given type (for relation pickers).
final relatedModelsProvider = relatedModelsByTypeNameProvider;
