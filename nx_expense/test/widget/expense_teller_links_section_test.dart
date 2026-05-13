import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nx_expense/data/providers.dart';
import 'package:nx_expense/features/expense/widgets/expense_teller_links_section.dart';

void main() {
  testWidgets('ExpenseTellerLinksFormSection shows title, add, empty state', (
    tester,
  ) async {
    const expenseId = 42;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          expenseTimelineLinksProvider(
            expenseId,
          ).overrideWith((ref) async => []),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: ExpenseTellerLinksFormSection(expenseId: expenseId),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Teller'), findsOneWidget);
    expect(find.byIcon(Icons.add_rounded), findsOneWidget);
    expect(find.text('No linked Teller transactions.'), findsOneWidget);
  });
}
