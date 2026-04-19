import 'package:nx_expense/domain/transfer/transfer.dart';
import 'package:nx_expense/domain/expense/expense_upsert.dart';
import 'package:nx_expense/domain/expense/expense_summary.dart';

/// Transfer uses the same upsert shape as expense for KGQL (name, attributes, tags, relations).
typedef TransferUpsert = ExpenseUpsert;

abstract class TransferRepository {
  Future<List<Transfer>> list({
    required DateTime rangeStart,
    required DateTime rangeEnd,
  });

  Future<Transfer?> getById(int id);

  Future<int> upsert(TransferUpsert payload);

  Future<void> deleteById(int id);

  Future<void> linkTransferToTellerTimeline({
    required int transferId,
    required String tellerEventId,
    required DateTime tellerEventTime,
  });

  Future<ExpenseSummary> listSummary({
    required DateTime rangeStart,
    required DateTime rangeEnd,
  });
}
