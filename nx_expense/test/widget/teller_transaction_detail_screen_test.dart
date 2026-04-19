import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:nx_expense/domain/teller/teller_transaction.dart';
import 'package:nx_expense/features/teller/teller_transaction_detail_page.dart';

void main() {
  testWidgets('TellerTransactionDetailScreen shows app bar and payload fields', (tester) async {
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
          builder: (context, state) => TellerTransactionDetailScreen(row: row),
        ),
      ],
    );

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();

    expect(find.text('Teller transaction'), findsOneWidget);
    expect(find.text('Coffee shop'), findsOneWidget);
    expect(find.text('debit'), findsOneWidget);
    expect(find.text('posted'), findsOneWidget);
    expect(find.text('tx-99'), findsOneWidget);
    expect(find.text('deleted'), findsOneWidget);
    expect(find.text('false'), findsOneWidget);
  });

  testWidgets('TellerTransactionDetailScreen shows deleted true when payload marked', (tester) async {
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
          builder: (context, state) => TellerTransactionDetailScreen(row: row),
        ),
      ],
    );

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();

    expect(find.text('true'), findsOneWidget);
  });
}
