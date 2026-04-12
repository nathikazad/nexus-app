import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:nx_db/nx_db.dart';

import '../app_theme.dart';
import '../expense_schema.dart';
import '../format.dart';
import '../providers/expense_providers.dart';
import '../reference_layout.dart';
import '../widgets/expense_app_end_drawer.dart';
import '../widgets/expense_date_range_bar.dart';

class TransfersListScreen extends ConsumerWidget {
  const TransfersListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final listAsync = ref.watch(transferListForUiProvider);
    final summaryAsync = ref.watch(transferListSummaryProvider);
    final schemaAsync = ref.watch(transferSchemaProvider);

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
                      ref.invalidate(transferSchemaProvider);
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
                        final items = _buildDateGroupedItems(models, schema);
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

  List<Widget> _buildDateGroupedItems(List<Model> models, ModelType schema) {
    final items = <Widget>[];
    String? lastDate;
    final amountKey = primaryNumberAttributeKey(schema);

    for (final m in models) {
      final dateStr = _dateLabel(m.createdAt);
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
          ),
        ),
      );
    }
    return items;
  }

  static String _dateLabel(String? iso) {
    if (iso == null || iso.isEmpty) return 'Unknown';
    try {
      final d = DateTime.parse(iso);
      return DateFormat('MMM d, y').format(d);
    } catch (_) {
      return iso;
    }
  }

  static num? _num(Model m, String key) {
    final raw = attributeValue(m, key);
    if (raw is num) return raw;
    return num.tryParse('$raw');
  }
}

class _TransferCard extends StatelessWidget {
  const _TransferCard({required this.title, required this.amount});

  final String title;
  final num? amount;

  @override
  Widget build(BuildContext context) {
    return Container(
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
    );
  }
}
