import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'providers/expense_providers.dart';
import 'screens/expense/expense_list_screen.dart';

/// Deep-linked expense list with its own filter/sort/search/selection state.
Widget scopedExpenseListScreen({
  required String title,
  required ExpenseFilter initialFilter,
  void Function(int expenseId)? onExpenseTap,
}) {
  return ProviderScope(
    overrides: [
      expenseListFilterProvider.overrideWith(ExpenseListFilterNotifier.new),
      expenseListSortProvider.overrideWith(ExpenseListSortNotifier.new),
      expenseListSearchQueryProvider.overrideWith(
        ExpenseListSearchQueryNotifier.new,
      ),
      expenseListSearchFieldExpandedProvider.overrideWith(
        ExpenseListSearchFieldExpandedNotifier.new,
      ),
      expenseListSelectionModeProvider.overrideWith(
        ExpenseListSelectionModeNotifier.new,
      ),
      expenseListSelectedIdsProvider.overrideWith(
        ExpenseListSelectedIdsNotifier.new,
      ),
      expenseDateRangeProvider.overrideWith(
        ScopedFilteredExpenseDateRangeNotifier.new,
      ),
      expenseListForUiProvider.overrideWith(
        (ref) => buildExpenseListForUi(ref),
      ),
      expenseListDisplayedProvider.overrideWith(
        (ref) => buildExpenseListDisplayed(ref),
      ),
      expenseListSummaryProvider.overrideWith(
        (ref) => buildExpenseListSummary(ref),
      ),
      expenseListSelectionSummaryProvider.overrideWith(
        buildExpenseListSelectionSummary,
      ),
    ],
    child: ExpenseListScreen(
      title: title,
      initialFilter: initialFilter,
      showFilterIcon: false,
      showDateRange: true,
      showSearch: true,
      showSelect: true,
      showDrawer: false,
      showActiveFilterChips: false,
      onExpenseTap: onExpenseTap,
    ),
  );
}
