import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:nx_db/auth.dart';
import 'package:nx_db/goals.dart';
import 'package:nx_db/kgql.dart';
import 'package:nx_db/riverpod.dart';

import 'package:nx_expense/data/expense/expense_struct.dart';
import 'package:nx_expense/data/expense/kgql_expense_repository.dart';
import 'package:nx_expense/data/schema/model_type_view_mapper.dart';
import 'package:nx_expense/data/teller/expense_timeline_api.dart';
import 'package:nx_expense/data/teller/teller_accounts_api.dart';
import 'package:nx_expense/data/teller/teller_timeline_api.dart';
import 'package:nx_expense/data/transfer/kgql_transfer_repository.dart';
import 'package:nx_expense/data/schema/kgql_schema_helpers.dart';
import 'package:nx_expense/domain/expense/expense.dart';
import 'package:nx_expense/domain/expense/expense_filter.dart';
import 'package:nx_expense/domain/expense/expense_repository.dart';
import 'package:nx_expense/domain/expense/expense_summary.dart';
import 'package:nx_expense/domain/expense/model_names.dart';
import 'package:nx_expense/domain/expense/related_model.dart';
import 'package:nx_expense/domain/schema/model_type_view.dart';
import 'package:nx_expense/domain/teller/teller_link.dart';
import 'package:nx_expense/domain/transfer/transfer.dart';
import 'package:nx_expense/domain/transfer/transfer_repository.dart';

/// GraphQL client for feature widgets that call data-layer APIs taking [GraphQLClient].
final expenseGraphqlClientProvider = Provider<GraphQLClient>(
  (ref) => ref.watch(graphqlClientProvider),
);

final expenseRepositoryProvider = Provider<ExpenseRepository>((ref) {
  return KgqlExpenseRepository(
    client: ref.watch(graphqlClientProvider),
    loadExpenseSchema: () => ref.read(expenseSchemaProvider.future),
  );
});

final transferRepositoryProvider = Provider<TransferRepository>((ref) {
  return KgqlTransferRepository(
    client: ref.watch(graphqlClientProvider),
    loadTransferSchema: () => ref.read(transferSchemaProvider.future),
  );
});

final expenseSchemaProvider = kgqlModelTypeByNameProvider(
  kExpenseModelTypeName,
);
final transferSchemaProvider = kgqlModelTypeByNameProvider(
  kTransferModelTypeName,
);

final expenseModelTypeDomainOptionsProvider =
    FutureProvider<ModelTypeDomainOptions>((ref) async {
      final client = ref.watch(expenseGraphqlClientProvider);
      return fetchModelTypeDomainOptions(
        client,
        modelTypeName: kExpenseModelTypeName,
      );
    });

final expenseDomainIdProvider = FutureProvider<int?>((ref) async {
  final options = await ref.watch(expenseModelTypeDomainOptionsProvider.future);
  return options.preferredDomain?.id;
});

final budgetExpenseGoalsMonthProvider =
    FutureProvider<ExpenseGoalMonthResponse>((ref) async {
      final client = ref.watch(expenseGraphqlClientProvider);
      final domainId = await ref.watch(expenseDomainIdProvider.future);
      final range = ref.watch(expenseDateRangeProvider);
      final monthStart = DateTime(range.start.year, range.start.month);
      return fetchExpenseGoalsMonth(
        client,
        monthStart: monthStart,
        domainId: domainId,
      );
    });

final expenseSchemaViewProvider = FutureProvider<ModelTypeView>((ref) async {
  final m = await ref.watch(expenseSchemaProvider.future);
  return modelTypeViewFromKgql(m);
});

final transferSchemaViewProvider = FutureProvider<ModelTypeView>((ref) async {
  final m = await ref.watch(transferSchemaProvider.future);
  return modelTypeViewFromKgql(m);
});

final expenseStructProvider = Provider<Map<String, dynamic>>((ref) {
  final async = ref.watch(expenseSchemaProvider);
  return async.maybeWhen(
    data: buildExpenseStruct,
    orElse: () => <String, dynamic>{},
  );
});

DateTimeRange _calendarMonthRange(DateTime forDay) {
  final start = DateTime(forDay.year, forDay.month);
  final end = DateTime(
    forDay.year,
    forDay.month + 1,
  ).subtract(const Duration(days: 1));
  return DateTimeRange(start: start, end: end);
}

bool _sameCalendarDate(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

/// True when [range] matches the calendar month containing [reference] (local),
/// using the same start/end convention as [ExpenseDateRangeNotifier]'s default.
bool isDateRangeCurrentCalendarMonth(
  DateTimeRange range, [
  DateTime? reference,
]) {
  final refDay = reference ?? DateTime.now();
  final cal = _calendarMonthRange(refDay);
  return _sameCalendarDate(range.start, cal.start) &&
      _sameCalendarDate(range.end, cal.end);
}

/// Default expense list date sort: newest first for the current calendar month,
/// oldest first for any other range.
ExpenseSortMode defaultExpenseSortModeForDateRange(
  DateTimeRange range, [
  DateTime? reference,
]) {
  return isDateRangeCurrentCalendarMonth(range, reference)
      ? ExpenseSortMode.dateDesc
      : ExpenseSortMode.dateAsc;
}

class ExpenseDateRangeNotifier extends Notifier<DateTimeRange> {
  @override
  DateTimeRange build() => _calendarMonthRange(DateTime.now());

  void setRange(DateTimeRange value) => state = value;
}

final expenseDateRangeProvider =
    NotifierProvider<ExpenseDateRangeNotifier, DateTimeRange>(
      ExpenseDateRangeNotifier.new,
    );

DateTimeRange kScopedFilteredExpenseDateRange() {
  final now = DateTime.now();
  return DateTimeRange(
    start: DateTime(2025, 1, 1),
    end: DateTime(now.year, now.month, now.day, 23, 59, 59, 999),
  );
}

class ScopedFilteredExpenseDateRangeNotifier extends ExpenseDateRangeNotifier {
  ScopedFilteredExpenseDateRangeNotifier([this.initialDateRange]);

  final DateTimeRange? initialDateRange;

  @override
  DateTimeRange build() =>
      initialDateRange ?? kScopedFilteredExpenseDateRange();
}

final expenseListProvider =
    FutureProvider.family<
      List<Expense>,
      ({ExpenseFilter? filter, DateTimeRange dateRange})
    >((ref, params) async {
      final repo = ref.watch(expenseRepositoryProvider);
      return repo.list(
        filter: params.filter,
        rangeStart: params.dateRange.start,
        rangeEnd: params.dateRange.end,
      );
    });

final transferListProvider = FutureProvider<List<Transfer>>((ref) async {
  final repo = ref.watch(transferRepositoryProvider);
  final range = ref.watch(expenseDateRangeProvider);
  return repo.list(rangeStart: range.start, rangeEnd: range.end);
});

final transferListForUiProvider = FutureProvider<List<Transfer>>((ref) async {
  final list = await ref.watch(transferListProvider.future);
  final range = ref.watch(expenseDateRangeProvider);
  final sorted = [...list];
  final desc = isDateRangeCurrentCalendarMonth(range);
  sorted.sort((a, b) {
    final c = transferDateSortKey(a).compareTo(transferDateSortKey(b));
    return desc ? -c : c;
  });
  return sorted;
});

final transferListSummaryProvider = FutureProvider<ExpenseSummary>((ref) async {
  final repo = ref.watch(transferRepositoryProvider);
  final range = ref.watch(expenseDateRangeProvider);
  return repo.listSummary(rangeStart: range.start, rangeEnd: range.end);
});

final expenseDetailProvider = FutureProvider.family<Expense?, int>((
  ref,
  id,
) async {
  final repo = ref.watch(expenseRepositoryProvider);
  return repo.getById(id);
});

final transferDetailProvider = FutureProvider.family<Transfer?, int>((
  ref,
  id,
) async {
  final repo = ref.watch(transferRepositoryProvider);
  return repo.getById(id);
});

final expenseTimelineLinksProvider =
    FutureProvider.family<List<TellerExpenseLink>, int>((ref, modelId) async {
      final client = ref.watch(expenseGraphqlClientProvider);
      return fetchExpenseTimelineLinks(client, modelId);
    });

final expenseSummaryProvider = FutureProvider<ExpenseSummary>((ref) async {
  final repo = ref.watch(expenseRepositoryProvider);
  return repo.globalSummary();
});

/// Relation picker: models of [typeName] with minimal struct.
final relatedModelsForTypeProvider =
    FutureProvider.family<List<RelatedModel>, String>((ref, typeName) async {
      final client = ref.watch(expenseGraphqlClientProvider);
      final models = await fetchKgqlModels(
        client,
        filter: {'model_type': typeName},
        struct: const {'id': true, 'name': true},
      );
      return [for (final m in models) RelatedModel(id: m.id, name: m.name)];
    });

/// Alias used by list filters, bulk actions, and relation pickers.
final relatedModelsProvider = relatedModelsForTypeProvider;

// ── Teller timeline (data + Riverpod) ─────────────────────────────────────────

final tellerAccountsProvider = FutureProvider<List<TellerLinkedAccount>>((
  ref,
) async {
  final base = ref.watch(imageBaseUrlProvider);
  final userId = ref.watch(userIdProvider);
  if (base == null || base.isEmpty || userId == null || userId.isEmpty) {
    return const [];
  }
  return fetchTellerAccounts(imageBaseUrl: base, userId: userId);
});

final tellerAccountNameByIdProvider = Provider<Map<String, String>>((ref) {
  final accounts = ref
      .watch(tellerAccountsProvider)
      .maybeWhen(data: (value) => value, orElse: () => const []);
  return {
    for (final account in accounts)
      if (account.accountId.trim().isNotEmpty)
        account.accountId: account.displayName,
  };
});

final tellerTransactionsProvider = FutureProvider<List<TellerTransaction>>((
  ref,
) async {
  final client = ref.watch(expenseGraphqlClientProvider);
  final range = ref.watch(expenseDateRangeProvider);
  return fetchTellerTimelineEvents(
    client,
    rangeStart: range.start,
    rangeEnd: range.end,
  );
});

bool _eventInLocalCalendarRange(DateTime eventUtc, DateTimeRange range) {
  final local = eventUtc.toLocal();
  final d = DateTime(local.year, local.month, local.day);
  final rs = DateTime(range.start.year, range.start.month, range.start.day);
  final re = DateTime(range.end.year, range.end.month, range.end.day);
  return !d.isBefore(rs) && !d.isAfter(re);
}

final tellerTransactionsInRangeProvider =
    Provider<AsyncValue<List<TellerTransaction>>>((ref) {
      final all = ref.watch(tellerTransactionsProvider);
      final range = ref.watch(expenseDateRangeProvider);
      return all.when(
        data: (rows) {
          final filtered = rows
              .where((r) => _eventInLocalCalendarRange(r.time, range))
              .toList();
          final desc = isDateRangeCurrentCalendarMonth(range);
          filtered.sort((a, b) {
            final c = a.time.compareTo(b.time);
            return desc ? -c : c;
          });
          return AsyncValue.data(filtered);
        },
        loading: () => const AsyncValue.loading(),
        error: (e, st) => AsyncValue.error(e, st),
      );
    });

class TellerListSummary {
  const TellerListSummary({required this.count, this.sumTotal});

  final int count;
  final num? sumTotal;
}

num? _parseTellerAmount(dynamic raw) {
  if (raw == null) return null;
  return num.tryParse(raw.toString().trim());
}

final tellerListSummaryProvider = Provider<AsyncValue<TellerListSummary>>((
  ref,
) {
  final async = ref.watch(tellerTransactionsInRangeProvider);
  return async.when(
    data: (rows) {
      num? sum;
      for (final r in rows) {
        final n = _parseTellerAmount(r.payload['amount']);
        if (n != null) {
          sum = (sum ?? 0) + n;
        }
      }
      return AsyncValue.data(
        TellerListSummary(count: rows.length, sumTotal: sum),
      );
    },
    loading: () => const AsyncValue.loading(),
    error: (e, st) => AsyncValue.error(e, st),
  );
});
