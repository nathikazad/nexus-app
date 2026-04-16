import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:nx_db/nx_db.dart';

import '../../app_theme.dart';
import '../../data/expense_timeline_api.dart';
import '../../data/teller_timeline_api.dart';
import '../../layout.dart';
import '../../providers/expense_providers.dart';
import '../../providers/teller_providers.dart';
import '../../util/format.dart';
import '../../widgets/expense_date_range_bar.dart';

/// Pick a Teller transaction to link to a model (Expense, Transfer, …); on success, pops back.
class TellerLinkPickerScreen extends ConsumerWidget {
  const TellerLinkPickerScreen({super.key, required this.modelId});

  final int modelId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final listAsync = ref.watch(tellerTransactionsInRangeProvider);
    final summaryAsync = ref.watch(tellerListSummaryProvider);
    final linksAsync = ref.watch(expenseTimelineLinksProvider(modelId));

    return Scaffold(
      backgroundColor: Colors.white,
      body: linksAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Links: $e')),
        data: (existingLinks) {
          final linkedIds = existingLinks
              .where((e) => e.isTellerTimelineEvent)
              .map((e) => e.eventId)
              .toSet();
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
                      IconButton(
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                        icon: const Icon(Icons.arrow_back, color: AppColors.slate400, size: 22),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                      Expanded(
                        child: Text(
                          'Link Teller',
                          style: refAppBarTitleLarge(),
                        ),
                      ),
                      const ExpenseDateRangeCalendarButton(),
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
                      ref.invalidate(expenseTimelineLinksProvider(modelId));
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
                        final candidates = rows.where((r) => !linkedIds.contains(r.eventId)).toList();
                        if (candidates.isEmpty) {
                          return Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.account_balance_outlined, size: 48, color: AppColors.slate300),
                                const SizedBox(height: 12),
                                Text(
                                  linkedIds.isEmpty && rows.isEmpty
                                      ? 'No Teller transactions in this range'
                                      : 'All transactions in this range are already linked',
                                  textAlign: TextAlign.center,
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
                        final items = _buildDateGroupedItems(
                          candidates,
                          context,
                          modelId,
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
              ),
            ],
          );
        },
      ),
    );
  }

  List<Widget> _buildDateGroupedItems(
    List<TellerTransactionRow> rows,
    BuildContext context,
    int modelId,
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
          child: _PickerTellerCard(
            row: r,
            modelId: modelId,
            pickerContext: context,
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

class _PickerTellerCard extends ConsumerWidget {
  const _PickerTellerCard({
    required this.row,
    required this.modelId,
    required this.pickerContext,
  });

  final TellerTransactionRow row;
  final int modelId;
  final BuildContext pickerContext;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final title = tellerTransactionTitleLine(row.payload);
    final amt = _parseAmount(row.payload['amount']);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () async {
          final client = ref.read(graphqlClientProvider);
          try {
            await linkExpenseToTimelineEvent(
              client,
              modelId: modelId,
              eventTime: row.time,
              eventId: row.eventId,
            );
            ref.invalidate(expenseTimelineLinksProvider(modelId));
            ref.invalidate(tellerTransactionsProvider);
            if (!pickerContext.mounted) return;
            Navigator.of(pickerContext).pop();
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

  static num? _parseAmount(dynamic raw) {
    if (raw == null) return null;
    return num.tryParse(raw.toString().trim());
  }
}
