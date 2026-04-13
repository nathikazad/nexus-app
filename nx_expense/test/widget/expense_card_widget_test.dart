import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nx_db/nx_db.dart';
import 'package:nx_expense/widgets/expense_card.dart';

void main() {
  testWidgets('ExpenseCard shows name and amount', (tester) async {
    final schema = ModelType(
      id: 1,
      name: 'Expense',
      attributes: [
        AttributeDefinition(key: 'cost', valueType: 'number'),
      ],
    );
    final model = Model(
      id: 42,
      name: 'Coffee',
      modelTypeId: 1,
      createdAt: '2025-01-15T12:00:00Z',
      attributes: {'cost': 4.5},
      tags: {'Category': ['Food']},
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ExpenseCard(
            model: model,
            schema: schema,
            onTap: () {},
          ),
        ),
      ),
    );

    expect(find.text('Coffee'), findsOneWidget);
    expect(find.textContaining(r'$'), findsWidgets);
  });
}
