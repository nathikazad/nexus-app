import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:nx_db/nx_db.dart';

import '../app_theme.dart';
import '../layout.dart';
import '../providers/expense_providers.dart';
import '../scoped_expense_list.dart';
import '../screens/expense/add_expense_screen.dart';
import '../screens/expense/expense_dashboard_screen.dart';
import '../screens/expense/expense_detail_screen.dart';
import '../screens/expense/expense_list_screen.dart';
import '../screens/tag/tag_system_form_screen.dart';
import '../screens/tag/tag_systems_screen.dart';
import '../screens/teller/teller_list_screen.dart';
import '../screens/teller/teller_transaction_detail_screen.dart';
import '../screens/transfers/transfer_detail_screen.dart';
import '../screens/transfers/transfers_list_screen.dart';
import 'desktop_nav.dart';

class DesktopShell extends ConsumerWidget {
  const DesktopShell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final index = ref.watch(desktopShellTabIndexProvider);
    final selecting = ref.watch(expenseListSelectionModeProvider);
    final showFab = (index == 0 && !selecting) || index == 3;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          NavigationRail(
            selectedIndex: index,
            onDestinationSelected: (i) {
              ref.read(desktopShellTabIndexProvider.notifier).state = i;
              if (i != 3) {
                ref.read(tagSystemsPanelSelectionProvider.notifier).state = null;
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
              child: Text(
                'EXPNS.',
                style: refAppBarTitleLarge(),
              ),
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
                icon: Icon(Icons.swap_horiz_outlined),
                selectedIcon: Icon(Icons.swap_horiz),
                label: Text('Transfers'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.sell_outlined),
                selectedIcon: Icon(Icons.sell),
                label: Text('Tags'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.account_balance_outlined),
                selectedIcon: Icon(Icons.account_balance),
                label: Text('Teller'),
              ),
            ],
          ),
          const VerticalDivider(width: 1, thickness: 1, color: AppColors.slate100),
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
                  } else {
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
        return const _TransfersPanels();
      case 3:
        return const _TagSystemsPanels();
      case 4:
        return const _TellerPanels();
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
    final panel3 = ref.watch(panel3StateProvider);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          width: 360,
          child: const ExpenseListScreen(),
        ),
        const VerticalDivider(width: 1, thickness: 1, color: AppColors.slate100),
        Expanded(
          child: selectedId != null
              ? ExpenseDetailScreen(
                  key: ValueKey('expense-detail-$selectedId'),
                  expenseId: selectedId,
                )
              : _emptyPanel('Select an expense'),
        ),
        const VerticalDivider(width: 1, thickness: 1, color: AppColors.slate100),
        SizedBox(
          width: 380,
          child: _ExpensePanel3(state: panel3),
        ),
      ],
    );
  }
}

class _ExpensePanel3 extends ConsumerWidget {
  const _ExpensePanel3({required this.state});

  final Panel3State state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    switch (state.type) {
      case Panel3Type.none:
        return const ColoredBox(
          color: Colors.white,
          child: SizedBox.expand(),
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
            relationFilters: {relName: {relId}},
            relationFilterLabels: {
              relName: {relId: relDisplayName},
            },
          ),
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
        SizedBox(
          width: 360,
          child: const TagSystemsScreen(embedded: true),
        ),
        const VerticalDivider(width: 1, thickness: 1, color: AppColors.slate100),
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

class _TransfersPanels extends ConsumerWidget {
  const _TransfersPanels();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedId = ref.watch(selectedTransferIdProvider);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          width: 360,
          child: const TransfersListScreen(),
        ),
        const VerticalDivider(width: 1, thickness: 1, color: AppColors.slate100),
        Expanded(
          child: selectedId != null
              ? TransferDetailScreen(
                  key: ValueKey('transfer-tab-$selectedId'),
                  transferId: selectedId,
                )
              : _emptyPanel('Select a transfer'),
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
        SizedBox(
          width: 360,
          child: const TellerListScreen(),
        ),
        const VerticalDivider(width: 1, thickness: 1, color: AppColors.slate100),
        Expanded(
          child: row != null
              ? TellerTransactionDetailScreen(
                  key: ValueKey('teller-tab-${row.eventId}'),
                  row: row,
                )
              : _emptyPanel('Select a transaction'),
        ),
      ],
    );
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
