import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nx_db/nx_db.dart';

import 'app_theme.dart';
import 'reference_layout.dart';
import 'screens/dashboard/dashboard_screen.dart';
import 'screens/expense/add_expense_screen.dart';
import 'screens/expense/expense_detail_screen.dart';
import 'screens/expense/expense_form_screen.dart';
import 'screens/expense/expense_list_screen.dart';
import 'screens/auth/expense_login_screen.dart';
import 'screens/transfers/transfers_list_screen.dart';
import 'screens/tag/tag_browser_screen.dart';
import 'screens/tag/tag_system_form_screen.dart';
import 'screens/tag/tag_systems_screen.dart';
import 'providers/expense_providers.dart';

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
          return Scaffold(
            // false: body stops above bottom nav so list/footer UIs aren't drawn under tabs.
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
        builder: (context, state) => const ExpenseFormScreen(),
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
    ],
  );
});
