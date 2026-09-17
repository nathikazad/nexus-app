import 'package:nx_expense/features/images/expense_images_page.dart';
import 'package:nx_expense/core/motion/expense_motion.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nx_db/auth.dart';

import 'package:nx_expense/domain/expense/expense_filter.dart';
import 'package:nx_expense/domain/teller/teller_transaction.dart';
import 'package:nx_expense/features/auth/expense_login_page.dart';
import 'package:nx_expense/features/budget/budget_page.dart';
import 'package:nx_expense/features/desktop/desktop_nav.dart';
import 'package:nx_expense/features/desktop/desktop_shell.dart';
import 'package:nx_expense/features/expense/expense_dashboard_page.dart';
import 'package:nx_expense/features/expense/expense_detail_page.dart';
import 'package:nx_expense/features/expense/expense_form_page.dart';
import 'package:nx_expense/features/expense/expense_list_page.dart';
import 'package:nx_expense/features/expense/scoped_expense_list.dart';
import 'package:nx_expense/features/orders/order_detail_page.dart';
import 'package:nx_expense/features/orders/order_link_picker_page.dart';
import 'package:nx_expense/features/orders/orders_list_page.dart';
import 'package:nx_expense/features/tag/tag_browser_page.dart';
import 'package:nx_expense/features/tag/tag_system_form_page.dart';
import 'package:nx_expense/features/tag/tag_systems_page.dart';
import 'package:nx_expense/features/teller/teller_expense_link_picker_page.dart';
import 'package:nx_expense/features/teller/teller_link_picker_page.dart';
import 'package:nx_expense/features/teller/teller_list_page.dart';

import 'package:nx_expense/features/teller/transaction_route_page.dart';

DateTimeRange? _dayRange(String value) {
  final date = DateTime.tryParse(value);
  return date == null ? null : DateTimeRange(start: date, end: date);
}

DateTimeRange? _routeDateRange(Uri uri) {
  final start = DateTime.tryParse(uri.queryParameters['start'] ?? '');
  final end = DateTime.tryParse(uri.queryParameters['end'] ?? '');
  if (start == null || end == null || end.isBefore(start)) return null;
  return DateTimeRange(start: start, end: end);
}

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = ValueNotifier<int>(0);
  var sessionChanged = false;
  ref.listen(authProvider, (previous, next) {
    final oldUser = previous?.value;
    final newUser = next.value;
    if (oldUser?.domainId != null &&
        newUser?.domainId != null &&
        oldUser!.sessionKey != newUser!.sessionKey) {
      sessionChanged = true;
    }
    refresh.value++;
  });
  final router = GoRouter(
    refreshListenable: refresh,
    initialLocation: '/expenses',
    redirect: (context, state) {
      final user = ref.read(authProvider).value;
      if (user == null && state.uri.path != '/login') {
        return Uri(
          path: '/login',
          queryParameters: {'next': state.uri.toString()},
        ).toString();
      }
      if (user != null && sessionChanged) {
        sessionChanged = false;
        return '/expenses';
      }
      if (user != null && state.uri.path == '/login') {
        final next = Uri.tryParse(state.uri.queryParameters['next'] ?? '');
        if (next != null &&
            !next.hasScheme &&
            !next.hasAuthority &&
            next.path.startsWith('/') &&
            next.path != '/login') {
          return next.toString();
        }
        return '/expenses';
      }
      if (state.uri.path == '/') return '/expenses';
      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => const ExpenseLoginScreen(),
      ),
      ShellRoute(
        builder: (context, state, child) => DesktopShell(
          uri: state.uri,
          child: child,
          buildDestination: (uri) => buildExpenseDestination(context, uri),
        ),
        routes: [
          for (final path in [
            '/expenses',
            '/dashboard',
            '/budget',
            '/teller',
            '/images',
            '/images/:id',
            '/orders',
            '/orders/:id',
            '/expense/:id/link-order',
            '/budget/detail/:goalId',
            '/tag-systems',
            '/expense/form/:id',
            '/expense/form',
            '/expense/:expenseId/link-teller',
            '/teller/link-expense',
            '/expense/:id',
            '/tag-system/form/:id',
            '/tag-system/form',
            '/tag-browser/:systemName',
            '/expenses/by-tag/:systemName/:tagNode',
            '/expenses/by-relation/:relName/:relId/:relDisplayName',
            '/expenses/by-date/:date',
            '/teller/transaction/:eventId',
          ])
            GoRoute(
              path: path,
              pageBuilder: (context, state) => ExpenseMotion.page(
                context,
                state,
                NavigationLocation(
                  uri: state.uri,
                  child: buildExpenseDestination(
                    context,
                    state.uri,
                    extra: state.extra,
                  ),
                ),
              ),
            ),
        ],
      ),
    ],
    errorBuilder: (context, state) =>
        const NavigationErrorScreen(message: 'Page not found'),
  );
  ref.onDispose(() {
    router.dispose();
    refresh.dispose();
  });
  return router;
});

/// Same destination builder for the active route and its desktop parent pane.
Widget buildExpenseDestination(BuildContext context, Uri uri, {Object? extra}) {
  final q = uri.queryParameters;
  try {
    switch (uri.pathSegments) {
      case ['expenses']:
        return const ExpenseListScreen();
      case ['dashboard']:
        return const DashboardScreen();
      case ['budget']:
        return const BudgetScreen();
      case ['teller']:
        return const TellerListScreen();
      case ['images']:
        return ExpenseImagesScreen(
          filter: const ['all', 'linked', 'unlinked'].contains(q['filter'])
              ? q['filter']!
              : 'all',
        );
      case ['images', final id]:
        return ExpenseImageDetailScreen(id: id, time: q['time']);
      case ['orders']:
        return const OrdersListScreen();
      case ['tag-systems']:
        return const TagSystemsScreen();
      case ['orders', final id]:
        return OrderDetailScreen(orderId: _modelId(id));
      case ['expense', final id, 'link-order']:
        return OrderLinkPickerScreen(expenseId: _modelId(id));
      case ['expense', final id, 'link-teller']:
        return TellerLinkPickerScreen(modelId: _modelId(id));
      case ['budget', 'detail', final id]:
        return BudgetDetailScreen(goalId: _modelId(id));
      case ['expense', 'form', final id]:
        return ExpenseFormScreen(expenseId: _modelId(id));
      case ['expense', 'form']:
        return ExpenseFormScreen(
          pendingTellerEventId: q['tellerEventId'],
          pendingTellerEventTime: DateTime.tryParse(q['tellerEventTime'] ?? ''),
          prefillName: q['prefillName'],
          prefillDescription: q['prefillDescription'],
          prefillAmount: num.tryParse(q['prefillAmount'] ?? ''),
          prefillDate: q['prefillDate'],
        );
      case ['expense', final id]:
        return ExpenseDetailScreen(expenseId: _modelId(id));
      case ['teller', 'transaction', final id]:
        return TransactionRouteScreen(eventId: id, time: q['time']);
      case ['teller', 'link-expense']:
        if (q['eventId'] case final String id) {
          return TransactionRouteScreen(
            eventId: id,
            time: q['time'],
            linkPicker: true,
          );
        }
        if (extra is TellerTransaction) {
          return TellerExpenseLinkPickerScreen(row: extra);
        }
        return const NavigationErrorScreen(message: 'Missing bank transaction');
      case ['tag-system', 'form', final id]:
        return TagSystemFormScreen(tagSystemId: _modelId(id));
      case ['tag-system', 'form']:
        return const TagSystemFormScreen();
      case ['tag-browser', final name]:
        return TagBrowserScreen(systemName: name);
      case ['expenses', 'by-tag', final system, final node]:
        return scopedExpenseListScreen(
          title: q['title'] ?? node,
          initialDateRange: _routeDateRange(uri),
          initialFilter: ExpenseFilter(
            tagFilters: [
              {
                'system': system,
                'node': node,
                'include_descendants': q['includeDescendants'] != 'false',
              },
            ],
          ),
        );
      case ['expenses', 'by-relation', final type, final rawId, final name]:
        final id = _modelId(rawId);
        return scopedExpenseListScreen(
          title: name,
          initialDateRange: _routeDateRange(uri),
          initialFilter: ExpenseFilter(
            relationFilters: {
              type: {id},
            },
            relationFilterLabels: {
              type: {id: name},
            },
          ),
        );
      case ['expenses', 'by-date', final date]:
        final range = _routeDateRange(uri) ?? _dayRange(date);
        if (range == null) throw const FormatException('Invalid date');
        return scopedExpenseListScreen(
          title: date,
          initialDateRange: range,
          initialFilter: const ExpenseFilter(),
        );
      default:
        return const NavigationErrorScreen(message: 'Page not found');
    }
  } on FormatException {
    return const NavigationErrorScreen(message: 'Invalid page address');
  }
}

int _modelId(String value) {
  final id = int.parse(value);
  if (id <= 0) throw const FormatException('Invalid model ID');
  return id;
}
