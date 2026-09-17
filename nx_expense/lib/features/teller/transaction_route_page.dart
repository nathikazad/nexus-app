import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nx_expense/data/providers.dart';
import 'package:nx_expense/features/desktop/desktop_nav.dart';
import 'teller_transaction_detail_page.dart';
import 'teller_expense_link_picker_page.dart';

/// Reloadable identity, independent of the selected list date range or `extra`.
class TransactionRouteScreen extends ConsumerWidget {
  const TransactionRouteScreen({
    super.key,
    required this.eventId,
    required this.time,
    this.linkPicker = false,
  });
  final String eventId;
  final String? time;
  final bool linkPicker;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final date = DateTime.tryParse(time ?? '');
    if (date == null) {
      return const NavigationErrorScreen(message: 'Missing transaction date');
    }
    final result = ref.watch(
      transactionRouteProvider((eventId: eventId, time: date)),
    );
    return result.when(
      loading: () => Scaffold(
        appBar: AppBar(leading: BackButton(onPressed: () => navBack(context))),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (error, stack) => Scaffold(
        appBar: AppBar(leading: BackButton(onPressed: () => navBack(context))),
        body: Center(
          child: TextButton(
            onPressed: () => ref.invalidate(
              transactionRouteProvider((eventId: eventId, time: date)),
            ),
            child: const Text('Unable to load transaction. Retry'),
          ),
        ),
      ),
      data: (row) => row == null
          ? const NavigationErrorScreen(message: 'Transaction not found')
          : linkPicker
          ? TellerExpenseLinkPickerScreen(row: row)
          : TellerTransactionDetailScreen(row: row),
    );
  }
}
