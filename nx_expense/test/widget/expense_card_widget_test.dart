import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nx_expense/domain/expense/expense.dart';
import 'package:nx_expense/domain/schema/model_type_view.dart';
import 'package:nx_expense/features/expense/widgets/expense_card.dart';

void main() {
  testWidgets('ExpenseCard shows name and amount', (tester) async {
    const schema = ModelTypeView(
      id: 1,
      name: 'Expense',
      attributes: [AttributeDefView(key: 'cost', valueType: 'number')],
    );
    const expense = Expense(
      id: 42,
      name: 'Coffee',
      modelTypeId: 1,
      createdAt: '2025-01-15T12:00:00Z',
      attributes: {'cost': 4.5},
      tags: {
        'Category': ['Food'],
      },
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ExpenseCard(expense: expense, schema: schema, onTap: () {}),
        ),
      ),
    );

    expect(find.text('Coffee'), findsOneWidget);
    expect(find.textContaining(r'$'), findsWidgets);
  });
}
