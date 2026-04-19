import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:nx_expense/data/providers.dart';
import 'package:nx_expense/domain/expense/expense_summary.dart';

final dashboardExpenseSummaryProvider = FutureProvider<ExpenseSummary>((
  ref,
) async {
  final repo = ref.watch(expenseRepositoryProvider);
  final range = ref.watch(expenseDateRangeProvider);
  return repo.dashboardSummary(
    rangeStart: range.start,
    rangeEnd: range.end,
  );
});

final spendByDayProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final repo = ref.watch(expenseRepositoryProvider);
  final range = ref.watch(expenseDateRangeProvider);
  return repo.spendByDay(
    rangeStart: range.start,
    rangeEnd: range.end,
  );
});

final spendByTagSystemProvider =
    FutureProvider.family<
      Map<String, dynamic>,
      ({String systemName, String? parentNode, int? level})
    >((ref, params) async {
      final repo = ref.watch(expenseRepositoryProvider);
      final range = ref.watch(expenseDateRangeProvider);
      return repo.spendByTagSystem(
        rangeStart: range.start,
        rangeEnd: range.end,
        systemName: params.systemName,
        parentNode: params.parentNode,
        level: params.level,
      );
    });

final spendByRelationProvider =
    FutureProvider.family<Map<String, dynamic>, String>((
      ref,
      targetTypeName,
    ) async {
      final repo = ref.watch(expenseRepositoryProvider);
      final range = ref.watch(expenseDateRangeProvider);
      return repo.spendByRelation(
        rangeStart: range.start,
        rangeEnd: range.end,
        targetTypeName: targetTypeName,
      );
    });
