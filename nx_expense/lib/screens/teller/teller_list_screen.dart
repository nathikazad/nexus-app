import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../app_theme.dart';
import '../../data/teller_timeline_api.dart';
import '../../layout.dart';
import '../../providers/teller_providers.dart';
import '../../util/format.dart';
import '../../widgets/expense_app_end_drawer.dart';
import '../../widgets/expense_date_range_bar.dart';
import '../../desktop/desktop_nav.dart';
import 'teller_transaction_detail_screen.dart';

class TellerListScreen extends ConsumerWidget {
  const TellerListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final listAsync = ref.watch(tellerTransactionsInRangeProvider);
    final summaryAsync = ref.watch(tellerListSummaryProvider);

    return Scaffold(
      backgroundColor: Colors.white,
      endDrawer: const ExpenseAppEndDrawer(),
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
                  if (Navigator.of(context).canPop())
                    IconButton(
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                      icon: const Icon(Icons.arrow_back, color: AppColors.slate400, size: 22),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  Expanded(child: Text('Teller', style: refAppBarTitleLarge())),
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
                  ref.invalidate(tellerTransactionsProvider);
                  await ref.read(tellerTransactionsProvider.future);
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
                  data: (rows) {
                    if (rows.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.account_balance_outlined, size: 48, color: AppColors.slate300),
                            const SizedBox(height: 12),
                            Text(
                              'No Teller transactions in this range',
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
                    final items = _buildDateGroupedItems(ref, rows);
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
      ),
    );
  }

  List<Widget> _buildDateGroupedItems(
    WidgetRef ref,
    List<TellerTransactionRow> rows,
  ) {
    final items = <Widget>[];
    String? lastDate;
    for (final r in rows) {
      final dateStr = _dateLabel(r.time);
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
          child: _TellerCard(
            row: r,
            onTap: (ctx) {
              if (isDesktopLayout(ctx)) {
                ref.read(selectedTellerRowProvider.notifier).state = r;
              } else {
                Navigator.of(ctx).push<void>(
                  MaterialPageRoute<void>(
                    builder: (_) => TellerTransactionDetailScreen(row: r),
                  ),
                );
              }
            },
          ),
        ),
      );
    }
    return items;
  }

  static String _dateLabel(DateTime t) {
    final d = t.toLocal();
    return DateFormat('MMM d, y').format(d);
  }
}

class _TellerCard extends StatelessWidget {
  const _TellerCard({required this.row, required this.onTap});

  final TellerTransactionRow row;
  final void Function(BuildContext context) onTap;

  @override
  Widget build(BuildContext context) {
    final title = tellerTransactionTitleLine(row.payload);
    final amt = _parseAmount(row.payload['amount']);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => onTap(context),
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

  static num? _parseAmount(dynamic raw) {
    if (raw == null) return null;
    return num.tryParse(raw.toString().trim());
  }
}
