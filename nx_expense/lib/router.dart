import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nx_db/nx_db.dart';

import 'screens/dashboard_screen.dart';
import 'screens/expense_detail_screen.dart';
import 'screens/expense_form_screen.dart';
import 'screens/expense_list_screen.dart';
import 'screens/tag_browser_screen.dart';
import 'screens/tag_system_form_screen.dart';
import 'screens/tag_systems_screen.dart';

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
        builder: (context, state) => const LoginPage(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return Scaffold(
            body: navigationShell,
            bottomNavigationBar: NavigationBar(
              selectedIndex: navigationShell.currentIndex,
              onDestinationSelected: navigationShell.goBranch,
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.receipt_long_outlined),
                  selectedIcon: Icon(Icons.receipt_long),
                  label: 'Expenses',
                ),
                NavigationDestination(
                  icon: Icon(Icons.bar_chart_outlined),
                  selectedIcon: Icon(Icons.bar_chart),
                  label: 'Dashboard',
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
        ],
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
      GoRoute(
        path: '/tag-systems',
        builder: (context, state) => const TagSystemsScreen(),
      ),
    ],
  );
});
