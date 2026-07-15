import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:nx_expense/data/providers.dart';
import 'package:nx_expense/domain/teller/teller_transaction.dart';
import 'package:nx_expense/features/teller/teller_transaction_detail_page.dart';

Widget _wrapWithProviderScope(GoRouter router) {
  return ProviderScope(
    overrides: [tellerAccountNameByIdProvider.overrideWith((ref) => const {})],
    child: MaterialApp.router(routerConfig: router),
  );
}

void main() {
  testWidgets(
    'TellerTransactionDetailScreen shows app bar and payload fields',
    (tester) async {
      final row = TellerTransactionRow(
        time: DateTime.utc(2026, 3, 15, 14, 30),
        eventId: 'e1',
        payload: {
          'date': '2026-03-15',
          'description': 'Coffee shop',
          'amount': '4.50',
          'type': 'debit',
          'status': 'posted',
          'id': 'tx-99',
        },
        linkedModels: const [],
      );

      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) =>
                TellerTransactionDetailScreen(row: row),
          ),
        ],
      );

      await tester.pumpWidget(_wrapWithProviderScope(router));
      await tester.pumpAndSettle();

      expect(find.text('External transaction'), findsOneWidget);
      expect(find.text('Source'), findsOneWidget);
      expect(find.text('Teller'), findsOneWidget);
      expect(find.text('Coffee shop'), findsOneWidget);
      expect(find.text('\$4.50'), findsOneWidget);
      expect(find.text('debit'), findsOneWidget);
      expect(find.text('posted'), findsOneWidget);
      expect(find.text('tx-99'), findsOneWidget);
      expect(find.text('deleted'), findsOneWidget);
      expect(find.text('false'), findsOneWidget);
    },
  );

  testWidgets(
    'TellerTransactionDetailScreen shows deleted true when payload marked',
    (tester) async {
      final row = TellerTransactionRow(
        time: DateTime.utc(2026, 3, 15, 14, 30),
        eventId: 'e-del',
        payload: {
          'date': '2026-03-15',
          'description': 'Old tx',
          'deleted': true,
          'type': 'debit',
          'status': 'posted',
          'id': 'tx-gone',
        },
        linkedModels: const [],
      );

      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) =>
                TellerTransactionDetailScreen(row: row),
          ),
        ],
      );

      await tester.pumpWidget(_wrapWithProviderScope(router));
      await tester.pumpAndSettle();

      expect(find.text('true'), findsOneWidget);
    },
  );

  testWidgets('New expense route includes teller date prefill', (tester) async {
    final row = TellerTransactionRow(
      time: DateTime(2026, 3, 15, 14, 30),
      eventId: 'e-prefill',
      payload: {
        'date': '2026-03-15',
        'description': 'Lunch counter',
        'amount': '-12.75',
        'type': 'debit',
        'status': 'posted',
        'id': 'tx-prefill',
      },
      linkedModels: const [],
    );
    Map<String, String>? query;

    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => TellerTransactionDetailScreen(row: row),
        ),
        GoRoute(
          path: '/expense/form',
          builder: (context, state) {
            query = state.uri.queryParameters;
            return const SizedBox.shrink();
          },
        ),
      ],
    );

    await tester.pumpWidget(_wrapWithProviderScope(router));
    await tester.pumpAndSettle();

    await tester.drag(find.byType(ListView), const Offset(0, -260));
    await tester.pumpAndSettle();
    await tester.tap(find.text('New expense'));
    await tester.pumpAndSettle();

    expect(query, isNotNull);
    expect(query!['prefillName'], 'Lunch counter');
    expect(query!['prefillAmount'], '-12.75');
    expect(query!['prefillDate'], '2026-03-15');
    expect(query!['tellerEventId'], 'e-prefill');
  });
}
