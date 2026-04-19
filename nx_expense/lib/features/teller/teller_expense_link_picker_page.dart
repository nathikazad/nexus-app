import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:nx_expense/core/formatting/format.dart';
import 'package:nx_expense/core/layout/layout.dart';
import 'package:nx_expense/core/theme/app_theme.dart';
import 'package:nx_expense/data/providers.dart';
import 'package:nx_expense/data/schema/kgql_schema_helpers.dart';
import 'package:nx_expense/data/teller/expense_timeline_api.dart';
import 'package:nx_expense/data/teller/teller_timeline_api.dart';
import 'package:nx_expense/domain/expense/expense.dart';
import 'package:nx_expense/domain/expense/model_names.dart';
import 'package:nx_expense/domain/teller/teller_transaction.dart';
import 'package:nx_expense/features/desktop/desktop_nav.dart';
import 'package:nx_expense/features/expense/expense_list_view_model.dart';
import 'package:nx_expense/features/expense/widgets/expense_date_range_bar.dart';

/// List + filters for picking an expense to link (also used in desktop Teller panel 3).
class TellerExpenseLinkPickerBody extends ConsumerWidget {
  const TellerExpenseLinkPickerBody({
    super.key,
    required this.row,
    this.embedded = false,
  });

  final TellerTransactionRow row;

  /// When true, successful link clears [tellerPanel3Provider] instead of [Navigator.pop].
  final bool embedded;

  static Set<int> _linkedExpenseIds(TellerTransactionRow r) {
    return {
      for (final m in r.linkedModels)
        if (m.modelTypeName == kExpenseModelTypeName) m.id,
    };
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final listAsync = ref.watch(expenseListForUiProvider);
    final schemaAsync = ref.watch(expenseSchemaViewProvider);
    final summaryAsync = ref.watch(expenseListSummaryProvider);
    final linked = _linkedExpenseIds(row);

    return schemaAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Schema: $e')),
      data: (schema) {
        final amountKey = primaryNumberAttributeKey(schema);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const ExpenseDateRangeBar(bottomPadding: 12),
            Padding(
              padding: const EdgeInsets.fromLTRB(RefLayout.px5, 0, RefLayout.px5, 4),
              child: summaryAsync.when(
                data: (s) => Text(
                  s.sumTotal != null ? '${s.count} · ${formatMoney(s.sumTotal)}' : '${s.count}',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppColors.slate500,
                  ),
                ),
                loading: () => Text(
                  '...',
                  style: GoogleFonts.inter(fontSize: 14, color: AppColors.slate500),
                ),
                error: (_, __) => const SizedBox.shrink(),
              ),
            ),
            Expanded(
              child: ColoredBox(
                color: AppColors.slate50.withValues(alpha: 0.5),
                child: listAsync.when(
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        'Error: $e',
                        style: GoogleFonts.inter(fontSize: 13, color: AppColors.slate500),
                      ),
                    ),
                  ),
                  data: (models) {
                    final candidates =
                        models.where((m) => !linked.contains(m.id)).toList();
                    if (candidates.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.receipt_long_outlined, size: 48, color: AppColors.slate300),
                            const SizedBox(height: 12),
                            Text(
                              linked.isEmpty && models.isEmpty
                                  ? 'No expenses in this range'
                                  : 'All expenses in range are already linked',
                              style: GoogleFonts.inter(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: AppColors.slate400,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      );
                    }
                    final items = _buildDateGroupedItems(
                      candidates,
                      amountKey,
                      row,
                      context,
                      embedded,
                    );
                    return ListView.builder(
                      padding: const EdgeInsets.fromLTRB(
                        RefLayout.px5,
                        8,
                        RefLayout.px5,
                        RefLayout.pb24,
                      ),
                      itemCount: items.length,
                      itemBuilder: (context, i) => items[i],
                    );
                  },
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  List<Widget> _buildDateGroupedItems(
    List<Expense> models,
    String? amountKey,
    TellerTransactionRow row,
    BuildContext pickerContext,
    bool embedded,
  ) {
    final items = <Widget>[];
    String? lastDate;
    for (final m in models) {
      final dateStr = modelDateCellLabel(m);
      if (dateStr != lastDate) {
        items.add(
          Padding(
            padding: EdgeInsets.only(top: lastDate == null ? 4 : 12, bottom: 4),
            child: Text(
              dateStr,
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.2,
                color: AppColors.slate400,
              ),
            ),
          ),
        );
        lastDate = dateStr;
      }
      items.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: _ExpensePickCard(
            expense: m,
            amountKey: amountKey,
            row: row,
            pickerContext: pickerContext,
            embedded: embedded,
          ),
        ),
      );
    }
    return items;
  }
}

/// Pick an expense to link to this Teller transaction (full-screen route).
class TellerExpenseLinkPickerScreen extends ConsumerWidget {
  const TellerExpenseLinkPickerScreen({super.key, required this.row});

  final TellerTransactionRow row;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                RefLayout.px5,
                RefLayout.appBarTop,
                RefLayout.px5,
                RefLayout.pb4,
              ),
              child: Row(
                children: [
                  IconButton(
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                    icon: const Icon(Icons.arrow_back, color: AppColors.slate400, size: 22),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  Expanded(
                    child: Text(
                      'Link expense',
                      style: refAppBarTitleLarge(),
                    ),
                  ),
                  const ExpenseDateRangeCalendarButton(),
                ],
              ),
            ),
          ),
          Expanded(
            child: TellerExpenseLinkPickerBody(row: row, embedded: false),
          ),
        ],
      ),
    );
  }
}

class _ExpensePickCard extends ConsumerWidget {
  const _ExpensePickCard({
    required this.expense,
    required this.amountKey,
    required this.row,
    required this.pickerContext,
    required this.embedded,
  });

  final Expense expense;
  final String? amountKey;
  final TellerTransactionRow row;
  final BuildContext pickerContext;
  final bool embedded;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final title = expense.name;
    num? amt;
    if (amountKey != null) {
      final raw = attributeValue(expense, amountKey!);
      if (raw is num) amt = raw;
      if (raw is String) amt = num.tryParse(raw);
    }
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () async {
          final client = ref.read(expenseGraphqlClientProvider);
          try {
            await linkModelToTimelineEvent(
              client,
              modelId: expense.id,
              eventTime: row.time,
              eventId: row.eventId,
            );
            if (!pickerContext.mounted) return;
            ref.invalidate(expenseTimelineLinksProvider(expense.id));
            if (isDesktopLayout(pickerContext)) {
              await refreshTellerSelectionAfterLinkChange(ref, row.eventId);
            } else {
              ref.invalidate(tellerTransactionsProvider);
            }
            if (!pickerContext.mounted) return;
            if (embedded) {
              closeTellerPanel3(ref);
            } else {
              Navigator.of(pickerContext).pop();
            }
          } catch (e) {
            if (pickerContext.mounted) {
              ScaffoldMessenger.of(pickerContext).showSnackBar(
                SnackBar(content: Text('$e')),
              );
            }
          }
        },
        borderRadius: BorderRadius.circular(RefLayout.rounded2xl),
        child: Ink(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(RefLayout.rounded2xl),
            border: Border.all(color: AppColors.slate100),
            boxShadow: refCardShadow,
          ),
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.slate900,
                  ),
                ),
              ),
              if (amt != null)
                Text(
                  formatMoney(amt),
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.teal600,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
