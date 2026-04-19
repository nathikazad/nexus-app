import 'package:nx_expense/domain/expense/expense.dart';
import 'package:nx_expense/domain/expense/expense_filter.dart';
import 'package:nx_expense/domain/expense/expense_upsert.dart';
import 'package:nx_expense/domain/expense/expense_summary.dart';
abstract class ExpenseRepository {
  Future<List<Expense>> list({
    ExpenseFilter? filter,
    required DateTime rangeStart,
    required DateTime rangeEnd,
  });

  Future<Expense?> getById(int id);

  /// Create or update; returns saved model id.
  Future<int> upsert(ExpenseUpsert payload);

  Future<void> deleteById(int id);

  /// Quick-create from FAB modal: name + amount + ignore=false.
  Future<int> createMinimalExpense({required String name, required num amount});

  Future<void> linkExpenseToTellerTimeline({
    required int expenseId,
    required String tellerEventId,
    required DateTime tellerEventTime,
  });

  Future<ExpenseSummary> globalSummary();

  Future<ExpenseSummary> dashboardSummary({
    required DateTime rangeStart,
    required DateTime rangeEnd,
  });

  Future<Map<String, dynamic>> spendByDay({
    required DateTime rangeStart,
    required DateTime rangeEnd,
  });

  Future<Map<String, dynamic>> spendByTagSystem({
    required DateTime rangeStart,
    required DateTime rangeEnd,
    required String systemName,
    String? parentNode,
    int? level,
  });

  Future<Map<String, dynamic>> spendByRelation({
    required DateTime rangeStart,
    required DateTime rangeEnd,
    required String targetTypeName,
  });
}
