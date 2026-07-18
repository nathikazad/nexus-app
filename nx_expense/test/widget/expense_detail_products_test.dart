import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nx_db/auth.dart';
import 'package:nx_expense/data/providers.dart';
import 'package:nx_expense/domain/expense/expense.dart';
import 'package:nx_expense/domain/expense/expense_product_line.dart';
import 'package:nx_expense/domain/expense/related_model.dart';
import 'package:nx_expense/domain/schema/model_type_view.dart';
import 'package:nx_expense/features/desktop/desktop_nav.dart';
import 'package:nx_expense/features/expense/expense_detail_page.dart';

void main() {
  testWidgets('mobile shows rich product lines and reconciles the total', (
    tester,
  ) async {
    await _setViewport(tester, const Size(390, 844));
    await tester.pumpWidget(_testApp());
    await tester.pumpAndSettle();

    expect(find.text('Products (2)'), findsOneWidget);
    expect(find.text("Luigi's Mini Sink Plunger"), findsOneWidget);
    expect(find.text('1 item · \$9.99 each'), findsOneWidget);
    expect(find.text('Products subtotal'), findsOneWidget);
    expect(find.text('Unallocated / tax / fees'), findsOneWidget);
    expect(find.byIcon(Icons.chevron_right), findsNothing);
    expect(
      find.byKey(const Key('product-related-expenses-action')),
      findsNWidgets(2),
    );
    expect(find.byKey(const Key('product-open-item-action')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('standalone web constrains detail content width', (tester) async {
    await _setViewport(tester, const Size(1440, 900));
    await tester.pumpWidget(_testApp());
    await tester.pumpAndSettle();

    final productCard = find.byKey(const ValueKey('expense-product-91'));
    expect(productCard, findsOneWidget);
    expect(tester.getSize(productCard).width, lessThanOrEqualTo(800));

    final relatedAction = find.byKey(
      const Key('product-related-expenses-action'),
    );
    final container = ProviderScope.containerOf(tester.element(productCard));
    await tester.tap(relatedAction.first);
    expect(
      container.read(panel3StackProvider).single.type,
      Panel3Type.relationExpenses,
    );
    expect(container.read(panel3StackProvider).single.id, 91);
    expect(tester.takeException(), isNull);
  });

  testWidgets('narrow desktop panel falls back without overflowing', (
    tester,
  ) async {
    await _setViewport(tester, const Size(620, 900));
    await tester.pumpWidget(_testApp());
    await tester.pumpAndSettle();

    expect(find.text('Products (2)'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

Future<void> _setViewport(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Widget _testApp() {
  return ProviderScope(
    overrides: [
      imageBaseUrlProvider.overrideWith((ref) => null),
      userIdProvider.overrideWith((ref) => null),
      expenseTimelineLinksProvider.overrideWith((ref, id) async => []),
    ],
    child: const MaterialApp(
      home: ExpenseDetailContent(
        schema: _schema,
        expense: _expense,
        expenseId: 2755,
      ),
    ),
  );
}

const _schema = ModelTypeView(
  id: 1,
  name: 'Expense',
  attributes: [
    AttributeDefView(key: 'cost', valueType: 'number'),
    AttributeDefView(key: 'date', valueType: 'date'),
  ],
);

const _expense = Expense(
  id: 2755,
  name: 'Sink Plunger and Soldering Station',
  description: 'AMAZON MKTPL',
  modelTypeId: 1,
  attributes: {'cost': -24.96, 'date': '2026-01-05'},
  relations: {
    'Product': [
      RelatedModel(id: 91, name: "Luigi's Mini Sink Plunger"),
      RelatedModel(id: 92, name: 'Helping Hands Magnifying Soldering Station'),
    ],
  },
  products: [
    ExpenseProductLine(
      id: 91,
      name: "Luigi's Mini Sink Plunger",
      brand: "Luigi's",
      itemUrl: 'https://example.com/plunger',
      price: 9.99,
      quantity: 1,
      unit: 'item',
    ),
    ExpenseProductLine(
      id: 92,
      name: 'Helping Hands Magnifying Soldering Station',
      price: 12.99,
      quantity: 1,
      unit: 'item',
    ),
  ],
);
