import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:nx_expense/core/formatting/format.dart';
import 'package:nx_expense/core/layout/layout.dart';
import 'package:nx_expense/core/theme/app_theme.dart';
import 'package:nx_expense/data/providers.dart';
import 'package:nx_expense/data/schema/kgql_schema_helpers.dart';
import 'package:nx_expense/domain/schema/model_type_view.dart';
import 'package:nx_expense/domain/transfer/transfer.dart';
import 'package:nx_expense/features/desktop/desktop_nav.dart';
import 'package:nx_expense/features/expense/widgets/expense_date_range_bar.dart';
import 'package:nx_expense/features/shell/expense_app_end_drawer.dart';

class TransfersListScreen extends ConsumerWidget {
  const TransfersListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final listAsync = ref.watch(transferListForUiProvider);
    final summaryAsync = ref.watch(transferListSummaryProvider);
    final schemaAsync = ref.watch(transferSchemaViewProvider);

    return Scaffold(
      backgroundColor: Colors.white,
      endDrawer: const ExpenseAppEndDrawer(),
      body: schemaAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: SelectableText('Schema: $e')),
        data: (schema) {
          return Column(
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
                      Expanded(child: Text('Transfers', style: refAppBarTitleLarge())),
                      const ExpenseDateRangeCalendarButton(),
                      const SizedBox(width: 4),
                      const ExpenseAppMenuButton(),
                    ],
                  ),
                ),
              ),
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
                  child: RefreshIndicator(
                    onRefresh: () async {
                      ref.invalidate(transferSchemaViewProvider);
                      ref.invalidate(transferListProvider);
                      ref.invalidate(transferListForUiProvider);
                      ref.invalidate(transferListSummaryProvider);
                    },
                    color: AppColors.teal600,
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
                        if (models.isEmpty) {
                          return Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.swap_horiz_rounded, size: 48, color: AppColors.slate300),
                                const SizedBox(height: 12),
                                Text(
                                  'No transfers in this range',
                                  style: GoogleFonts.inter(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.slate400,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }
                        final items = _buildDateGroupedItems(context, ref, models, schema);
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
              ),
            ],
          );
        },
      ),
    );
  }

  List<Widget> _buildDateGroupedItems(
    BuildContext context,
    WidgetRef ref,
    List<Transfer> models,
    ModelTypeView schema,
  ) {
    final items = <Widget>[];
    String? lastDate;
    final amountKey = primaryNumberAttributeKey(schema);

    for (final m in models) {
      final dateStr = transferCellDateLabel(m);
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
          child: _TransferCard(
            title: transferDisplayTitle(m),
            amount: amountKey != null ? _num(m, amountKey) : null,
            onOpen: () => navToTransferDetailDirect(context, ref, m.id),
          ),
        ),
      );
    }
    return items;
  }

  static num? _num(Transfer m, String key) {
    final raw = attributeValue(m, key);
    if (raw is num) return raw;
    return num.tryParse('$raw');
  }
}

class _TransferCard extends StatelessWidget {
  const _TransferCard({
    required this.title,
    required this.amount,
    required this.onOpen,
  });

  final String title;
  final num? amount;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onOpen,
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
              if (amount != null)
                Text(
                  formatMoney(amount),
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
