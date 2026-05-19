import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:nx_expense/core/formatting/format.dart';
import 'package:nx_expense/core/layout/layout.dart';
import 'package:nx_expense/core/theme/app_theme.dart';
import 'package:nx_expense/data/providers.dart';
import 'package:nx_expense/domain/order/order.dart';
import 'package:nx_expense/features/expense/widgets/expense_date_range_bar.dart';
import 'package:nx_expense/features/shell/expense_app_end_drawer.dart';

class OrdersListScreen extends ConsumerWidget {
  const OrdersListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final listAsync = ref.watch(orderListForUiProvider);
    final summaryAsync = ref.watch(orderListSummaryProvider);

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
                  IconButton(
                    visualDensity: VisualDensity.compact,
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
                    onPressed: () => context.pop(),
                  ),
                  const SizedBox(width: 4),
                  Expanded(child: Text('Orders', style: refAppBarTitleLarge())),
                  const ExpenseDateRangeCalendarButton(),
                  const SizedBox(width: 4),
                  const ExpenseAppMenuButton(),
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
                child: listAsync.when(
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
                    if (orders.isEmpty) {
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
                              'No orders in this range',
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
                    final items = _buildDateGroupedItems(context, orders);
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
    BuildContext context,
    List<Order> orders,
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
          child: _OrderRow(
            order: order,
            onOpen: () => context.push('/orders/${order.id}'),
          ),
        ),
      );
    }
    return items;
  }
}

class _OrderRow extends StatelessWidget {
  const _OrderRow({required this.order, required this.onOpen});

  final Order order;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final itemLabel = order.itemCount == 1
        ? '1 item'
        : '${order.itemCount} items';
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
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      order.orderNumber,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.slate900,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${order.companyName ?? 'Unknown'} · $itemLabel',
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
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
