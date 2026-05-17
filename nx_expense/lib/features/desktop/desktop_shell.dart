import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:nx_db/auth.dart';

import 'package:nx_expense/core/layout/layout.dart';
import 'package:nx_expense/core/theme/app_theme.dart';
import 'package:nx_expense/data/teller/teller_timeline_api.dart';
import 'package:nx_expense/domain/expense/expense_filter.dart';
import 'package:nx_expense/features/budget/budget_page.dart';
import 'package:nx_expense/features/expense/expense_list_view_model.dart';
import 'package:nx_expense/features/expense/expense_dashboard_page.dart';
import 'package:nx_expense/features/expense/expense_detail_page.dart';
import 'package:nx_expense/features/expense/expense_form_page.dart';
import 'package:nx_expense/features/expense/expense_list_page.dart';
import 'package:nx_expense/features/expense/scoped_expense_list.dart';
import 'package:nx_expense/features/expense/widgets/expense_date_range_bar.dart';
import 'package:nx_expense/features/tag/tag_system_form_page.dart';
import 'package:nx_expense/features/tag/tag_systems_page.dart';
import 'package:nx_expense/features/teller/teller_expense_link_picker_page.dart';
import 'package:nx_expense/features/teller/teller_list_page.dart';
import 'package:nx_expense/features/teller/teller_transfer_link_picker_page.dart';
import 'package:nx_expense/features/teller/teller_transfer_quick_create_page.dart';
import 'package:nx_expense/features/teller/teller_transaction_detail_page.dart';
import 'package:nx_expense/features/transfers/transfer_detail_page.dart';
import 'desktop_nav.dart';
import 'panel_chrome.dart';

class DesktopShell extends ConsumerWidget {
  const DesktopShell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final index = ref.watch(desktopShellTabIndexProvider);
    final selecting = ref.watch(expenseListSelectionModeProvider);
    final showFab = (index == 0 && !selecting) || index == 4;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          NavigationRail(
            selectedIndex: index,
            onDestinationSelected: (i) {
              ref.read(desktopShellTabIndexProvider.notifier).state = i;
              if (i != 4) {
                ref.read(tagSystemsPanelSelectionProvider.notifier).state =
                    null;
              }
              if (i != 3) {
                ref.read(tellerPanel3Provider.notifier).state = null;
              }
            },
            labelType: NavigationRailLabelType.all,
            backgroundColor: Colors.white,
            indicatorColor: AppColors.slate100,
            selectedIconTheme: const IconThemeData(color: AppColors.teal600),
            unselectedIconTheme: const IconThemeData(color: AppColors.slate400),
            selectedLabelTextStyle: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.teal600,
            ),
            unselectedLabelTextStyle: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: AppColors.slate400,
            ),
            leading: Padding(
              padding: const EdgeInsets.fromLTRB(8, 16, 8, 8),
              child: Text('EXPNS.', style: refAppBarTitleLarge()),
            ),
            trailing: Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: IconButton(
                icon: const Icon(Icons.logout, color: AppColors.slate400),
                tooltip: 'Log out',
                onPressed: () async {
                  await ref.read(authProvider.notifier).logout();
                  if (context.mounted) context.go('/login');
                },
              ),
            ),
            destinations: const [
              NavigationRailDestination(
                icon: Icon(Icons.account_balance_wallet_outlined),
                selectedIcon: Icon(Icons.account_balance_wallet),
                label: Text('Expenses'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.bar_chart_outlined),
                selectedIcon: Icon(Icons.bar_chart),
                label: Text('Stats'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.savings_outlined),
                selectedIcon: Icon(Icons.savings),
                label: Text('Budget'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.account_balance_outlined),
                selectedIcon: Icon(Icons.account_balance),
                label: Text('Teller'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.sell_outlined),
                selectedIcon: Icon(Icons.sell),
                label: Text('Tags'),
              ),
            ],
          ),
          const VerticalDivider(
            width: 1,
            thickness: 1,
            color: AppColors.slate100,
          ),
          Expanded(child: _DesktopContent(index: index)),
        ],
      ),
      floatingActionButton: showFab
          ? Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: refFabShadow,
              ),
              child: FloatingActionButton(
                onPressed: () {
                  if (index == 0) {
                    showAddExpenseModal(context);
                  } else if (index == 4) {
                    navToTagSystemCreate(context, ref);
                  }
                },
                backgroundColor: AppColors.teal600,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: const CircleBorder(),
                child: const Icon(Icons.add_circle_outline, size: 28),
              ),
            )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      floatingActionButtonAnimator: FloatingActionButtonAnimator.scaling,
    );
  }
}

class _DesktopContent extends ConsumerWidget {
  const _DesktopContent({required this.index});

  final int index;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    switch (index) {
      case 0:
        return const _ExpensesPanels();
      case 1:
        return const DashboardScreen();
      case 2:
        return const BudgetScreen();
      case 3:
        return const _TellerPanels();
      case 4:
        return const _TagSystemsPanels();
      default:
        return const SizedBox.shrink();
    }
  }
}

class _ExpensesPanels extends ConsumerWidget {
  const _ExpensesPanels();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedId = ref.watch(selectedExpenseIdProvider);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(width: 360, child: const ExpenseListScreen()),
        const VerticalDivider(
          width: 1,
          thickness: 1,
          color: AppColors.slate100,
        ),
        Expanded(
          child: selectedId != null
              ? ExpenseDetailScreen(
                  key: ValueKey('expense-detail-$selectedId'),
                  expenseId: selectedId,
                )
              : _emptyPanel('Select an expense'),
        ),
        const VerticalDivider(
          width: 1,
          thickness: 1,
          color: AppColors.slate100,
        ),
        SizedBox(width: 380, child: _ExpensePanel3()),
      ],
    );
  }
}

class _ExpensePanel3 extends ConsumerWidget {
  const _ExpensePanel3();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stack = ref.watch(panel3StackProvider);
    if (stack.isEmpty) {
      return const ColoredBox(color: Colors.white, child: SizedBox.expand());
    }

    final top = stack.last;
    return SizedBox.expand(child: _buildPanel3Content(context, ref, top));
  }

  Widget _buildPanel3Content(
    BuildContext context,
    WidgetRef ref,
    Panel3State state,
  ) {
    switch (state.type) {
      case Panel3Type.none:
        return const ColoredBox(color: Colors.white, child: SizedBox.expand());
      case Panel3Type.expenseDetail:
        return ExpenseDetailScreen(
          key: ValueKey('p3-expense-${state.id}'),
          expenseId: state.id!,
        );
      case Panel3Type.transfer:
        return TransferDetailScreen(
          key: ValueKey('transfer-${state.id}'),
          transferId: state.id!,
        );
      case Panel3Type.teller:
        return TellerTransactionDetailScreen(
          key: ValueKey('teller-${state.tellerRow!.eventId}'),
          row: state.tellerRow!,
        );
      case Panel3Type.relationExpenses:
        final relName = state.label!;
        final relId = state.id!;
        final relDisplayName = state.secondaryLabel!;
        return scopedExpenseListScreen(
          title: relDisplayName,
          initialFilter: ExpenseFilter(
            relationFilters: {
              relName: {relId},
            },
            relationFilterLabels: {
              relName: {relId: relDisplayName},
            },
          ),
          onExpenseTap: (id) => navToExpenseDetailFromPanel3(context, ref, id),
        );
      case Panel3Type.tagExpenses:
        final systemName = state.label!;
        final tagNode = state.secondaryLabel!;
        return scopedExpenseListScreen(
          title: tagNode,
          initialFilter: ExpenseFilter(
            tagFilters: [
              {
                'system': systemName,
                'node': tagNode,
                'include_descendants': true,
              },
            ],
          ),
          onExpenseTap: (id) => navToExpenseDetailFromPanel3(context, ref, id),
        );
    }
  }
}

class _TagSystemsPanels extends ConsumerWidget {
  const _TagSystemsPanels();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sel = ref.watch(tagSystemsPanelSelectionProvider);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(width: 360, child: const TagSystemsScreen(embedded: true)),
        const VerticalDivider(
          width: 1,
          thickness: 1,
          color: AppColors.slate100,
        ),
        Expanded(
          child: sel == null
              ? _emptyPanel('Select a tag system or add one')
              : TagSystemFormScreen(
                  key: ValueKey(
                    sel.isCreate ? 'tag-create' : 'tag-edit-${sel.editId}',
                  ),
                  tagSystemId: sel.isCreate ? null : sel.editId,
                  embedded: true,
                ),
        ),
      ],
    );
  }
}

class _TellerPanels extends ConsumerWidget {
  const _TellerPanels();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final row = ref.watch(selectedTellerRowProvider);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(width: 360, child: const TellerListScreen()),
        const VerticalDivider(
          width: 1,
          thickness: 1,
          color: AppColors.slate100,
        ),
        Expanded(
          child: row != null
              ? TellerTransactionDetailScreen(
                  key: ValueKey('teller-tab-${row.eventId}'),
                  row: row,
                )
              : _emptyPanel('Select a transaction'),
        ),
        const VerticalDivider(
          width: 1,
          thickness: 1,
          color: AppColors.slate100,
        ),
        SizedBox(width: 380, child: _TellerPanel3()),
      ],
    );
  }
}

class _TellerPanel3 extends ConsumerWidget {
  const _TellerPanel3();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(tellerPanel3Provider);
    if (state == null) {
      return const ColoredBox(color: Colors.white, child: SizedBox.expand());
    }
    switch (state.kind) {
      case TellerPanel3Kind.expense:
        return ExpenseDetailScreen(
          key: ValueKey('teller-p3-expense-${state.detailId}'),
          expenseId: state.detailId!,
        );
      case TellerPanel3Kind.transfer:
        return TransferDetailScreen(
          key: ValueKey('teller-p3-transfer-${state.detailId}'),
          transferId: state.detailId!,
        );
      case TellerPanel3Kind.linkExpensePicker:
        final row = state.tellerRow!;
        return PanelChrome(
          title: 'Link expense',
          leading: IconButton(
            icon: const Icon(
              Icons.arrow_back,
              color: AppColors.slate400,
              size: 22,
            ),
            onPressed: () => closeTellerPanel3(ref),
          ),
          actions: [
            const Padding(
              padding: EdgeInsets.only(right: 4),
              child: ExpenseDateRangeCalendarButton(),
            ),
          ],
          body: TellerExpenseLinkPickerBody(row: row, embedded: true),
        );
      case TellerPanel3Kind.linkTransferPicker:
        final row = state.tellerRow!;
        return PanelChrome(
          title: 'Link transfer',
          leading: IconButton(
            icon: const Icon(
              Icons.arrow_back,
              color: AppColors.slate400,
              size: 22,
            ),
            onPressed: () => closeTellerPanel3(ref),
          ),
          actions: [
            const Padding(
              padding: EdgeInsets.only(right: 4),
              child: ExpenseDateRangeCalendarButton(),
            ),
          ],
          body: TellerTransferLinkPickerBody(row: row, embedded: true),
        );
      case TellerPanel3Kind.newExpenseForm:
        final row = state.tellerRow!;
        final p = row.payload;
        final amt = num.tryParse(p['amount']?.toString().trim() ?? '');
        return PanelChrome(
          title: 'New expense',
          leading: IconButton(
            icon: const Icon(
              Icons.arrow_back,
              color: AppColors.slate400,
              size: 22,
            ),
            onPressed: () => closeTellerPanel3(ref),
          ),
          body: ExpenseFormScreen(
            embedded: true,
            pendingTellerEventId: row.eventId,
            pendingTellerEventTime: row.time,
            prefillName: tellerTransactionTitleLine(p),
            prefillAmount: amt,
            prefillDate: p['date']?.toString(),
          ),
        );
      case TellerPanel3Kind.newTransferCreate:
        final row = state.tellerRow!;
        return PanelChrome(
          title: 'New transfer',
          leading: IconButton(
            icon: const Icon(
              Icons.arrow_back,
              color: AppColors.slate400,
              size: 22,
            ),
            onPressed: () => closeTellerPanel3(ref),
          ),
          body: TellerTransferQuickCreateScreen(row: row, embedded: true),
        );
    }
  }
}

Widget _emptyPanel(String message) {
  return ColoredBox(
    color: AppColors.slate50.withValues(alpha: 0.5),
    child: Center(
      child: Text(
        message,
        style: GoogleFonts.inter(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: AppColors.slate400,
        ),
      ),
    ),
  );
}
