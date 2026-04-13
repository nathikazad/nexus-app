import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nx_db/nx_db.dart';

import '../data/teller_timeline_api.dart';
import 'expense_providers.dart';

/// All Teller timeline events for the signed-in user (network).
final tellerTransactionsProvider = FutureProvider<List<TellerTransactionRow>>((ref) async {
  final client = ref.watch(graphqlClientProvider);
  return fetchTellerTimelineEvents(client);
});

bool _eventInLocalCalendarRange(DateTime eventUtc, DateTimeRange range) {
  final local = eventUtc.toLocal();
  final d = DateTime(local.year, local.month, local.day);
  final rs = DateTime(range.start.year, range.start.month, range.start.day);
  final re = DateTime(range.end.year, range.end.month, range.end.day);
  return !d.isBefore(rs) && !d.isAfter(re);
}

/// [tellerTransactionsProvider] filtered by [expenseDateRangeProvider], newest first.
final tellerTransactionsInRangeProvider =
    Provider<AsyncValue<List<TellerTransactionRow>>>((ref) {
  final all = ref.watch(tellerTransactionsProvider);
  final range = ref.watch(expenseDateRangeProvider);
  return all.when(
    data: (rows) {
      final filtered = rows.where((r) => _eventInLocalCalendarRange(r.time, range)).toList();
      filtered.sort((a, b) => b.time.compareTo(a.time));
      return AsyncValue.data(filtered);
    },
    loading: () => const AsyncValue.loading(),
    error: (e, st) => AsyncValue.error(e, st),
  );
});

/// Count and sum of signed amounts in the visible window (from Teller `amount` string).
final tellerListSummaryProvider = Provider<AsyncValue<TellerListSummary>>((ref) {
  final async = ref.watch(tellerTransactionsInRangeProvider);
  return async.when(
    data: (rows) {
      num? sum;
      for (final r in rows) {
        final n = _parseAmount(r.payload['amount']);
        if (n != null) {
          sum = (sum ?? 0) + n;
        }
      }
      return AsyncValue.data(TellerListSummary(count: rows.length, sumTotal: sum));
    },
    loading: () => const AsyncValue.loading(),
    error: (e, st) => AsyncValue.error(e, st),
  );
});

num? _parseAmount(dynamic raw) {
  if (raw == null) return null;
  return num.tryParse(raw.toString().trim());
}

class TellerListSummary {
  const TellerListSummary({required this.count, this.sumTotal});

  final int count;
  final num? sumTotal;
}
