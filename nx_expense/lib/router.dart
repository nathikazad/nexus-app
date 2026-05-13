import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nx_db/auth.dart';

import 'package:nx_expense/core/layout/layout.dart';
import 'package:nx_expense/core/theme/app_theme.dart';
import 'package:nx_expense/domain/expense/expense_filter.dart';
import 'package:nx_expense/domain/teller/teller_transaction.dart';
import 'package:nx_expense/features/auth/expense_login_page.dart';
import 'package:nx_expense/features/desktop/desktop_nav.dart';
import 'package:nx_expense/features/desktop/desktop_shell.dart';
import 'package:nx_expense/features/expense/expense_dashboard_page.dart';
import 'package:nx_expense/features/expense/expense_detail_page.dart';
import 'package:nx_expense/features/expense/expense_form_page.dart';
import 'package:nx_expense/features/expense/expense_list_page.dart';
import 'package:nx_expense/features/expense/expense_list_view_model.dart';
import 'package:nx_expense/features/expense/scoped_expense_list.dart';
import 'package:nx_expense/features/tag/tag_browser_page.dart';
import 'package:nx_expense/features/tag/tag_system_form_page.dart';
import 'package:nx_expense/features/tag/tag_systems_page.dart';
import 'package:nx_expense/features/teller/teller_expense_link_picker_page.dart';
import 'package:nx_expense/features/teller/teller_link_picker_page.dart';
import 'package:nx_expense/features/teller/teller_list_page.dart';
import 'package:nx_expense/features/teller/teller_transfer_link_picker_page.dart';
import 'package:nx_expense/features/teller/teller_transfer_quick_create_page.dart';
import 'package:nx_expense/features/transfers/transfer_detail_page.dart';
import 'package:nx_expense/features/transfers/transfer_form_page.dart';
import 'package:nx_expense/features/transfers/transfer_relation_picker_page.dart';
import 'package:nx_expense/features/transfers/transfers_list_page.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = ValueNotifier<int>(0);
  ref.listen(authProvider, (_, __) => refresh.value++);

  return GoRouter(
    refreshListenable: refresh,
    initialLocation: '/expenses',
    redirect: (context, state) {
      final user = ref.read(authProvider).value;
      final path = state.uri.path;
      if (path == '/') {
        return '/expenses';
      }
      if (user == null && path != '/login') {
        return '/login';
      }
      if (user != null && path == '/login') {
        return '/expenses';
      }
      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => const ExpenseLoginScreen(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          final selecting = ref.watch(expenseListSelectionModeProvider);
          final showFab = navigationShell.currentIndex == 0 && !selecting;

          if (isDesktopLayout(context)) {
            return Stack(
              fit: StackFit.expand,
              children: [
                Offstage(offstage: true, child: navigationShell),
                const Positioned.fill(child: DesktopShell()),
              ],
            );
          }

          return Scaffold(
            extendBody: false,
            body: navigationShell,
            floatingActionButton: showFab
                ? Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: refFabShadow,
                    ),
                    child: FloatingActionButton(
                      onPressed: () => showAddExpenseModal(context),
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
            bottomNavigationBar: NavigationBar(
              selectedIndex: navigationShell.currentIndex,
              onDestinationSelected: navigationShell.goBranch,
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.account_balance_wallet_outlined),
                  selectedIcon: Icon(Icons.account_balance_wallet),
                  label: 'Expenses',
                ),
                NavigationDestination(
                  icon: Icon(Icons.bar_chart_outlined),
                  selectedIcon: Icon(Icons.bar_chart),
                  label: 'Stats',
                ),
                NavigationDestination(
                  icon: Icon(Icons.swap_horiz_outlined),
                  selectedIcon: Icon(Icons.swap_horiz),
                  label: 'Transfers',
                ),
                NavigationDestination(
                  icon: Icon(Icons.account_balance_outlined),
                  selectedIcon: Icon(Icons.account_balance),
                  label: 'Teller',
                ),
              ],
            ),
          );
        },
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/expenses',
                builder: (context, state) => const ExpenseListScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/dashboard',
                builder: (context, state) => const DashboardScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/transfers',
                builder: (context, state) => const TransfersListScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/teller',
                builder: (context, state) => const TellerListScreen(),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/tag-systems',
        builder: (context, state) => const TagSystemsScreen(),
      ),
      GoRoute(
        path: '/expense/form/:id',
        builder: (context, state) {
          final id = int.parse(state.pathParameters['id']!);
          return ExpenseFormScreen(expenseId: id);
        },
      ),
      GoRoute(
        path: '/expense/form',
        builder: (context, state) {
          final q = state.uri.queryParameters;
          final tid = q['tellerEventId'];
          final tt = q['tellerEventTime'];
          final pa = q['prefillAmount'];
          return ExpenseFormScreen(
            pendingTellerEventId: tid,
            pendingTellerEventTime: tt != null ? DateTime.tryParse(tt) : null,
            prefillName: q['prefillName'],
            prefillDescription: q['prefillDescription'],
            prefillAmount: pa != null ? num.tryParse(pa) : null,
          );
        },
      ),
      GoRoute(
        path: '/pick-transfer-relation',
        builder: (context, state) {
          final extra = state.extra;
          if (extra is! TransferRelationPickerExtra) {
            return const Scaffold(
              body: Center(child: Text('Invalid navigation')),
            );
          }
          return TransferRelationPickerScreen(
            allowMultiple: extra.allowMultiple,
            initialIds: extra.initialIds,
          );
        },
      ),
      GoRoute(
        path: '/transfer/form',
        builder: (context, state) {
          final from = state.uri.queryParameters['fromExpenseId'];
          return TransferFormScreen(
            prefillFromExpenseId: from != null ? int.tryParse(from) : null,
          );
        },
      ),
      GoRoute(
        path: '/transfer/form/:id',
        builder: (context, state) {
          final id = int.parse(state.pathParameters['id']!);
          return TransferFormScreen(transferId: id);
        },
      ),
      GoRoute(
        path: '/transfer/:id',
        builder: (context, state) {
          final id = int.parse(state.pathParameters['id']!);
          return TransferDetailScreen(transferId: id);
        },
      ),
      GoRoute(
        path: '/expense/:expenseId/link-teller',
        builder: (context, state) {
          final id = int.parse(state.pathParameters['expenseId']!);
          return TellerLinkPickerScreen(modelId: id);
        },
      ),
      GoRoute(
        path: '/transfer/:transferId/link-teller',
        builder: (context, state) {
          final id = int.parse(state.pathParameters['transferId']!);
          return TellerLinkPickerScreen(modelId: id);
        },
      ),
      GoRoute(
        path: '/teller/link-expense',
        builder: (context, state) {
          final extra = state.extra;
          if (extra is! TellerTransaction) {
            return const Scaffold(
              body: Center(child: Text('Missing Teller transaction')),
            );
          }
          return TellerExpenseLinkPickerScreen(row: extra);
        },
      ),
      GoRoute(
        path: '/teller/link-transfer',
        builder: (context, state) {
          final extra = state.extra;
          if (extra is! TellerTransaction) {
            return const Scaffold(
              body: Center(child: Text('Missing Teller transaction')),
            );
          }
          return TellerTransferLinkPickerScreen(row: extra);
        },
      ),
      GoRoute(
        path: '/teller/transfer-create',
        builder: (context, state) {
          final extra = state.extra;
          if (extra is! TellerTransaction) {
            return const Scaffold(
              body: Center(child: Text('Missing Teller transaction')),
            );
          }
          return TellerTransferQuickCreateScreen(row: extra);
        },
      ),
      GoRoute(
        path: '/expense/:id',
        builder: (context, state) {
          final id = int.parse(state.pathParameters['id']!);
          return ExpenseDetailScreen(expenseId: id);
        },
      ),
      GoRoute(
        path: '/tag-system/form/:id',
        builder: (context, state) {
          final id = int.parse(state.pathParameters['id']!);
          return TagSystemFormScreen(tagSystemId: id);
        },
      ),
      GoRoute(
        path: '/tag-system/form',
        builder: (context, state) => const TagSystemFormScreen(),
      ),
      GoRoute(
        path: '/tag-browser/:systemName',
        builder: (context, state) {
          final name = Uri.decodeComponent(state.pathParameters['systemName']!);
          return TagBrowserScreen(systemName: name);
        },
      ),
      GoRoute(
        path: '/expenses/by-tag/:systemName/:tagNode',
        builder: (context, state) {
          final systemName = Uri.decodeComponent(
            state.pathParameters['systemName']!,
          );
          final tagNode = Uri.decodeComponent(state.pathParameters['tagNode']!);
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
        },
      ),
      GoRoute(
        path: '/expenses/by-relation/:relName/:relId/:relDisplayName',
        builder: (context, state) {
          final relName = Uri.decodeComponent(state.pathParameters['relName']!);
          final relId = int.parse(state.pathParameters['relId']!);
          final relDisplayName = Uri.decodeComponent(
            state.pathParameters['relDisplayName']!,
          );
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
          );
        },
      ),
    ],
  );
});
