import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:nx_expense/data/providers.dart';
import 'package:nx_expense/data/schema/kgql_schema_helpers.dart';
import 'package:nx_expense/features/expense/expense_dashboard_view_model.dart';
import 'package:nx_expense/domain/expense/expense.dart';
import 'package:nx_expense/domain/expense/expense_filter.dart';
import 'package:nx_expense/domain/expense/expense_summary.dart';

class ExpenseListFilterNotifier extends Notifier<ExpenseFilter?> {
  @override
  ExpenseFilter? build() => null;

  void setFilter(ExpenseFilter? value) => state = value;
}

final expenseListFilterProvider =
    NotifierProvider<ExpenseListFilterNotifier, ExpenseFilter?>(
      ExpenseListFilterNotifier.new,
    );

class ExpenseListSortNotifier extends Notifier<ExpenseSortMode> {
  @override
  ExpenseSortMode build() {
    final range = ref.read(expenseDateRangeProvider);
    ref.listen<DateTimeRange>(expenseDateRangeProvider, (prev, next) {
      final mode = state;
      final isDateSort =
          mode == ExpenseSortMode.dateAsc || mode == ExpenseSortMode.dateDesc;
      if (!isDateSort) return;
      final want = defaultExpenseSortModeForDateRange(next);
      if (state != want) state = want;
    });
    return defaultExpenseSortModeForDateRange(range);
  }

  void setSort(ExpenseSortMode value) => state = value;
}

/// True when the sort icon should show as "custom" (non-default for range, or amount sort).
bool expenseListSortIsActive(ExpenseSortMode mode, DateTimeRange range) {
  if (mode == ExpenseSortMode.amountAsc || mode == ExpenseSortMode.amountDesc) {
    return true;
  }
  return mode != defaultExpenseSortModeForDateRange(range);
}

final expenseListSortProvider =
    NotifierProvider<ExpenseListSortNotifier, ExpenseSortMode>(
      ExpenseListSortNotifier.new,
    );

Future<List<Expense>> buildExpenseListForUi(Ref ref) async {
  final filter = ref.watch(expenseListFilterProvider);
  final dateRange = ref.watch(expenseDateRangeProvider);
  final sortMode = ref.watch(expenseListSortProvider);

  final list = await ref.watch(
    expenseListProvider((filter: filter, dateRange: dateRange)).future,
  );

  final schema = await ref.watch(expenseSchemaViewProvider.future);
  final amountKey = schema.primaryNumberAttributeKey;
  var filtered = list;
  if (amountKey != null && filter != null) {
    if (filter.minAmount != null || filter.maxAmount != null) {
      filtered = filtered.where((m) {
        final v = numAttr(m, amountKey);
        if (filter.minAmount != null && v < filter.minAmount!) return false;
        if (filter.maxAmount != null && v > filter.maxAmount!) return false;
        return true;
      }).toList();
    }
  }

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

  final sorted = [...filtered];
  switch (sortMode) {
    case ExpenseSortMode.dateDesc:
      sorted.sort((a, b) => expenseDateSortKey(b).compareTo(expenseDateSortKey(a)));
    case ExpenseSortMode.dateAsc:
      sorted.sort((a, b) => expenseDateSortKey(a).compareTo(expenseDateSortKey(b)));
    case ExpenseSortMode.amountDesc:
    case ExpenseSortMode.amountAsc:
      if (amountKey != null) {
        sorted.sort((a, b) {
          final va = numAttr(a, amountKey);
          final vb = numAttr(b, amountKey);
          return sortMode == ExpenseSortMode.amountDesc
              ? vb.compareTo(va)
              : va.compareTo(vb);
        });
      }
  }
  return sorted;
}

final expenseListForUiProvider = FutureProvider<List<Expense>>(
  (ref) => buildExpenseListForUi(ref),
);

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

List<Expense> filterExpenseModelsBySearch(List<Expense> models, String query) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return models;

  bool matches(Expense m) {
    if (m.name.toLowerCase().contains(q)) return true;
    final d = m.description;
    if (d != null && d.isNotEmpty && d.toLowerCase().contains(q)) return true;
    return false;
  }

  return models.where(matches).toList();
}

Future<List<Expense>> buildExpenseListDisplayed(Ref ref) async {
  final list = await ref.watch(expenseListForUiProvider.future);
  final q = ref.watch(expenseListSearchQueryProvider);
  return filterExpenseModelsBySearch(list, q);
}

final expenseListDisplayedProvider = FutureProvider<List<Expense>>(
  (ref) => buildExpenseListDisplayed(ref),
);

Future<ExpenseSummary> buildExpenseListSummary(Ref ref) async {
  final list = await ref.watch(expenseListDisplayedProvider.future);
  final schema = await ref.watch(expenseSchemaViewProvider.future);
  final key = schema.primaryNumberAttributeKey;

  final tallied = [
    for (final m in list)
      if (!expenseIgnoredForTotals(m)) m,
  ];

  num? sum;
  if (key != null) {
    sum = 0;
    for (final m in tallied) {
      sum = sum! + numAttr(m, key);
    }
  }

  return ExpenseSummary(count: tallied.length, sumTotal: sum);
}

final expenseListSummaryProvider = FutureProvider<ExpenseSummary>(
  (ref) => buildExpenseListSummary(ref),
);

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

ExpenseSummary? buildExpenseListSelectionSummary(Ref ref) {
  if (!ref.watch(expenseListSelectionModeProvider)) return null;
  final displayed = ref.watch(expenseListDisplayedProvider);
  final selected = ref.watch(expenseListSelectedIdsProvider);
  final list = displayed.maybeWhen(data: (l) => l, orElse: () => null);
  if (list == null) {
    return ExpenseSummary(count: selected.length, sumTotal: null);
  }
  final schema = ref
      .watch(expenseSchemaViewProvider)
      .maybeWhen(data: (s) => s, orElse: () => null);
  final key = schema?.primaryNumberAttributeKey;
  num? sum;
  if (key != null) {
    sum = 0;
    for (final m in list) {
      if (!selected.contains(m.id)) continue;
      if (expenseIgnoredForTotals(m)) continue;
      sum = sum! + numAttr(m, key);
    }
  }
  return ExpenseSummary(count: selected.length, sumTotal: sum);
}

final expenseListSelectionSummaryProvider = Provider<ExpenseSummary?>(
  (ref) => buildExpenseListSelectionSummary(ref),
);

/// Refetch the expense list for the current [expenseListFilterProvider] and
/// [expenseDateRangeProvider] (respects scoped overrides), plus list/global/range summaries.
void invalidateExpenseListCache(WidgetRef ref) {
  final filter = ref.read(expenseListFilterProvider);
  final dateRange = ref.read(expenseDateRangeProvider);
  ref.invalidate(
    expenseListProvider((filter: filter, dateRange: dateRange)),
  );
  ref.invalidate(expenseListSummaryProvider);
  ref.invalidate(expenseSummaryProvider);
  ref.invalidate(dashboardExpenseSummaryProvider);
  ref.invalidate(spendByDayProvider);
}
