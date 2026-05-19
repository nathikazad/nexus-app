import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:nx_db/kgql.dart';

import 'package:nx_expense/core/formatting/format.dart';
import 'package:nx_expense/core/layout/layout.dart';
import 'package:nx_expense/core/theme/app_theme.dart';
import 'package:nx_expense/data/providers.dart';
import 'package:nx_expense/domain/expense/model_names.dart';
import 'package:nx_expense/domain/order/order.dart';
import 'package:nx_expense/features/expense/widgets/expense_date_range_bar.dart';

class OrderLinkPickerScreen extends ConsumerWidget {
  const OrderLinkPickerScreen({super.key, required this.expenseId});

  final int expenseId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ordersAsync = ref.watch(orderListForUiProvider);
    final summaryAsync = ref.watch(orderListSummaryProvider);
    final expenseAsync = ref.watch(expenseDetailProvider(expenseId));

    return Scaffold(
      backgroundColor: Colors.white,
      body: expenseAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: SelectableText('Expense: $e')),
        data: (expense) {
          final linkedIds =
              expense?.relations?[kOrderModelTypeName]
                  ?.map((m) => m.id)
                  .toSet() ??
              <int>{};
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
                        constraints: const BoxConstraints(
                          minWidth: 40,
                          minHeight: 40,
                        ),
                        icon: const Icon(
                          Icons.arrow_back,
                          color: AppColors.slate400,
                          size: 22,
                        ),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                      Expanded(
                        child: Text('Link Order', style: refAppBarTitleLarge()),
                      ),
                      const ExpenseDateRangeCalendarButton(),
                    ],
                  ),
                ),
              ),
              const ExpenseDateRangeBar(bottomPadding: 12),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  RefLayout.px5,
                  0,
                  RefLayout.px5,
                  4,
                ),
                child: summaryAsync.when(
                  data: (s) => Text(
                    s.sumTotal != null
                        ? '${s.count} · ${formatMoney(s.sumTotal)}'
                        : '${s.count}',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: AppColors.slate500,
                    ),
                  ),
                  loading: () => Text(
                    '...',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: AppColors.slate500,
                    ),
                  ),
                  error: (_, __) => const SizedBox.shrink(),
                ),
              ),
              Expanded(
                child: ColoredBox(
                  color: AppColors.slate50.withValues(alpha: 0.5),
                  child: RefreshIndicator(
                    onRefresh: () async {
                      ref.invalidate(orderSchemaProvider);
                      ref.invalidate(orderListProvider);
                      ref.invalidate(orderListForUiProvider);
                      ref.invalidate(orderListSummaryProvider);
                    },
                    color: AppColors.teal600,
                    child: ordersAsync.when(
                      loading: () =>
                          const Center(child: CircularProgressIndicator()),
                      error: (e, _) => Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            'Error: $e',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              color: AppColors.slate500,
                            ),
                          ),
                        ),
                      ),
                      data: (orders) {
                        final candidates = orders
                            .where((o) => !linkedIds.contains(o.id))
                            .toList();
                        if (candidates.isEmpty) {
                          return Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.inventory_2_outlined,
                                  size: 48,
                                  color: AppColors.slate300,
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  orders.isEmpty
                                      ? 'No orders in this range'
                                      : 'All orders in this range are already linked',
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
    List<Order> orders,
    BuildContext context,
  ) {
    final items = <Widget>[];
    String? lastDate;

    for (final order in orders) {
      final dateStr = formatModelDate(order.orderDate);
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
          child: _PickerOrderCard(
            order: order,
            expenseId: expenseId,
            pickerContext: context,
          ),
        ),
      );
    }
    return items;
  }
}

class _PickerOrderCard extends ConsumerWidget {
  const _PickerOrderCard({
    required this.order,
    required this.expenseId,
    required this.pickerContext,
  });

  final Order order;
  final int expenseId;
  final BuildContext pickerContext;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () async {
          final client = ref.read(expenseGraphqlClientProvider);
          try {
            await setKgqlModel(
              client,
              SetModelRequest(
                id: expenseId,
                relations: [
                  ModelRelation(
                    modelType: kOrderModelTypeName,
                    link: [order.id],
                  ),
                ],
              ),
            );
            ref.invalidate(expenseDetailProvider(expenseId));
            if (!pickerContext.mounted) return;
            Navigator.of(pickerContext).pop();
          } catch (e) {
            if (pickerContext.mounted) {
              ScaffoldMessenger.of(
                pickerContext,
              ).showSnackBar(SnackBar(content: Text('$e')));
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      order.companyName ?? 'Unknown',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.slate900,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      order.orderNumber,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: AppColors.slate500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Text(
                formatMoney(order.total),
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
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
