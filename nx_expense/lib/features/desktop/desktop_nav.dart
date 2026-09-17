import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nx_expense/data/teller/teller_timeline_api.dart';
import 'package:nx_expense/data/teller/expense_timeline_api.dart';

const double kDesktopBreakpoint = 1100;
bool isDesktopLayout(BuildContext context) =>
    MediaQuery.sizeOf(context).width >= kDesktopBreakpoint;

/// Each pane carries its own location, so clicking a parent pane preserves the
/// correct origin rather than borrowing the rightmost pane's route.
class NavigationLocation extends InheritedWidget {
  const NavigationLocation({
    super.key,
    required this.uri,
    required super.child,
  });
  final Uri uri;
  static Uri of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<NavigationLocation>()?.uri ??
      GoRouterState.of(context).uri;
  @override
  bool updateShouldNotify(NavigationLocation oldWidget) => oldWidget.uri != uri;
}

Uri? navigationParent(Uri uri) {
  final value = uri.queryParameters['from'];
  final parent = value == null ? null : Uri.tryParse(value);
  if (parent == null ||
      parent.hasScheme ||
      parent.hasAuthority ||
      !parent.path.startsWith('/') ||
      parent.path == '/login' ||
      parent == uri) {
    return null;
  }
  return parent;
}

String navigationSection(Uri uri) {
  for (var i = 0; i < 12; i++) {
    if (const [
      '/expenses',
      '/dashboard',
      '/budget',
      '/teller',
      '/orders',
      '/tag-systems',
      '/images',
    ].contains(uri.path)) {
      break;
    }
    final parent = navigationParent(uri);
    if (parent == null) break;
    uri = parent;
  }
  final path = uri.path;
  if (path.startsWith('/images')) return '/images';
  if (path.startsWith('/orders')) return '/orders';
  if (path.startsWith('/teller')) return '/teller';
  if (path.startsWith('/tag-')) return '/tag-systems';
  if (path.startsWith('/budget')) return '/budget';
  if (path == '/dashboard') return '/dashboard';
  return '/expenses';
}

Future<T?> navPush<T>(BuildContext context, String location, {Object? extra}) {
  final destination = Uri.parse(location);
  var origin = NavigationLocation.of(context);
  // Bound deep drill-down URLs while retaining the immediate source page.
  if (origin.toString().length > 6000) {
    origin = origin.replace(
      queryParameters: {...origin.queryParameters}..remove('from'),
    );
  }
  return context.push<T>(
    destination
        .replace(
          queryParameters: {
            ...destination.queryParameters,
            'from': origin.toString(),
          },
        )
        .toString(),
    extra: extra,
  );
}

bool navCanBack(BuildContext context) {
  final location = NavigationLocation.of(context);
  return navigationParent(location) != null ||
      location.path != navigationSection(location);
}

void navBack(BuildContext context, {String? fallback}) {
  final router = GoRouter.of(context);
  final location = NavigationLocation.of(context);
  if (GoRouterState.of(context).uri == location && router.canPop()) {
    router.pop();
  } else {
    router.go(
      navigationParent(location)?.toString() ??
          fallback ??
          navigationSection(location),
    );
  }
}

class NavigationLoadingScreen extends StatelessWidget {
  const NavigationLoadingScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(leading: BackButton(onPressed: () => navBack(context))),
    body: const Center(child: CircularProgressIndicator()),
  );
}

class NavigationErrorScreen extends StatelessWidget {
  const NavigationErrorScreen({super.key, required this.message});
  final String message;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(leading: BackButton(onPressed: () => navBack(context))),
    body: Center(child: Text(message)),
  );
}

void navToExpenseDetail(BuildContext context, WidgetRef ref, int id) =>
    navPush(context, '/expense/$id');
void navToExpenseDetailFromPanel3(
  BuildContext context,
  WidgetRef ref,
  int id,
) => navToExpenseDetail(context, ref, id);
void navToRelationExpenses(
  BuildContext context,
  WidgetRef ref, {
  required String relName,
  required int relId,
  required String displayName,
}) => navPush(
  context,
  '/expenses/by-relation/${Uri.encodeComponent(relName)}/$relId/${Uri.encodeComponent(displayName)}',
);
void navToTagExpenses(
  BuildContext context,
  WidgetRef ref, {
  required String systemName,
  required String tagNode,
}) => navPush(
  context,
  '/expenses/by-tag/${Uri.encodeComponent(systemName)}/${Uri.encodeComponent(tagNode)}',
);
void navAfterExpenseDelete(BuildContext context, WidgetRef ref) =>
    context.go('/expenses');
void navExpenseDetailBack(
  BuildContext context,
  WidgetRef ref, {
  required int expenseId,
}) => navBack(context);
void navTellerTxDetailBack(
  BuildContext context,
  WidgetRef ref,
  TellerTransactionRow row,
) => navBack(context, fallback: '/teller');
void navToTagSystemEdit(BuildContext context, WidgetRef ref, int id) =>
    navPush(context, '/tag-system/form/$id');
void navToTagSystemCreate(BuildContext context, WidgetRef ref) =>
    navPush(context, '/tag-system/form');
void navTagSystemFormBack(BuildContext context, WidgetRef ref) =>
    navBack(context, fallback: '/tag-systems');
void navToExpenseFromTellerLink(BuildContext context, WidgetRef ref, int id) =>
    navToExpenseDetail(context, ref, id);

String transactionLocation(
  TellerTransactionRow row, {
  bool linkPicker = false,
}) => Uri(
  path: linkPicker
      ? '/teller/link-expense'
      : '/teller/transaction/${Uri.encodeComponent(row.eventId)}',
  queryParameters: {
    'time': formatTimelineLocalTimestamp(row.time),
    if (linkPicker) 'eventId': row.eventId,
  },
).toString();
void navToTransaction(BuildContext context, TellerTransactionRow row) =>
    navPush(context, transactionLocation(row));
