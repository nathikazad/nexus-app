import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nx_db/auth.dart';
import 'package:nx_expense/domain/suggestion/expense_suggestion.dart';
import 'package:nx_expense/features/suggestions/suggestion_review_page.dart';
import 'package:nx_expense/features/suggestions/suggestion_state.dart';

void main() {
  testWidgets('review inbox presents transaction and merchant evidence', (
    tester,
  ) async {
    ExpenseSuggestion? selected;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          imageBaseUrlProvider.overrideWith((ref) => null),
          userIdProvider.overrideWith((ref) => null),
          openExpenseSuggestionsProvider.overrideWith(
            (ref) async => [_suggestion],
          ),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: SuggestionInboxPane(
              desktop: true,
              onSelected: (value) => selected = value,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('1 ready for review'), findsOneWidget);
    expect(find.text('AMAZON MKTPL'), findsOneWidget);
    expect(find.text('Waveshare CM5 Mini Base Board'), findsOneWidget);
    expect(find.text(r'$31.49'), findsOneWidget);

    await tester.tap(find.text('AMAZON MKTPL'));
    expect(selected?.id, 26);
  });

  testWidgets('detail shows the graph hierarchy and decision controls', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          imageBaseUrlProvider.overrideWith((ref) => null),
          userIdProvider.overrideWith((ref) => null),
          openExpenseSuggestionsProvider.overrideWith(
            (ref) async => [_suggestion],
          ),
          selectedExpenseSuggestionIdProvider.overrideWith((ref) => 26),
        ],
        child: const MaterialApp(
          home: Scaffold(body: SuggestionDetailPane(mobile: true)),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('BANK TRANSACTION'), findsOneWidget);
    expect(find.text('AMAZON TRANSACTION'), findsOneWidget);
    expect(find.text('EXPENSE'), findsOneWidget);
    expect(find.text('PRODUCTS (1)'), findsOneWidget);
    expect(find.text('Waveshare'), findsOneWidget);
    expect(find.text('Reject'), findsOneWidget);
    expect(find.text('Revise'), findsOneWidget);
    expect(find.text('Accept'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Revise'));
    await tester.pumpAndSettle();
    expect(find.text('Revise suggestion'), findsOneWidget);
    expect(find.text('What should the AI change?'), findsOneWidget);

    await tester.tap(find.text('Send for revision'));
    await tester.pump();
    expect(find.text('Tell the AI what should change.'), findsOneWidget);
  });

  testWidgets(
    'grouped detail shows the expense total and every bank transaction',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            imageBaseUrlProvider.overrideWith((ref) => null),
            userIdProvider.overrideWith((ref) => null),
            openExpenseSuggestionsProvider.overrideWith(
              (ref) async => [_groupedSuggestion],
            ),
            selectedExpenseSuggestionIdProvider.overrideWith((ref) => 172),
          ],
          child: const MaterialApp(
            home: Scaffold(body: SuggestionDetailPane(mobile: false)),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('BANK TRANSACTIONS (2)'), findsOneWidget);
      expect(find.text(r'$27.00'), findsOneWidget);
      expect(find.text(r'$15.00'), findsOneWidget);
      expect(find.text(r'$12.00'), findsOneWidget);
      expect(find.text('SF LAUNDROMAT WASH'), findsOneWidget);
      expect(find.text('SF LAUNDROMAT DRY'), findsOneWidget);
    },
  );
}

const _groupedSuggestion = ExpenseSuggestion(
  id: 172,
  caseKey: 'transaction-expense:bofa:30859',
  status: 'open',
  title: 'Combined laundromat expense',
  reason: 'Both charges are from one visit.',
  bankTransactions: [
    SuggestionEvent(
      eventId: 30859,
      source: 'bofa',
      eventType: 'transaction',
      description: 'SF LAUNDROMAT WASH',
      date: '2026-06-29',
      amount: -15,
    ),
    SuggestionEvent(
      eventId: 30858,
      source: 'bofa',
      eventType: 'transaction',
      description: 'SF LAUNDROMAT DRY',
      date: '2026-06-29',
      amount: -12,
    ),
  ],
  provider: null,
  expense: SuggestedExpense(id: null, name: 'Laundry', cost: -27),
  tags: [],
  products: [],
);

const _suggestion = ExpenseSuggestion(
  id: 26,
  caseKey: 'transaction-expense:teller:2207',
  status: 'open',
  title: 'Link Amazon purchase',
  reason: 'The exact amount and nearby date identify this Amazon order.',
  bankTransactions: [
    SuggestionEvent(
      eventId: 2207,
      source: 'teller',
      eventType: 'teller_transaction',
      description: 'AMAZON MKTPL',
      date: '2026-01-30',
      amount: -31.49,
      accountLast4: '8134',
    ),
  ],
  provider: SuggestionEvent(
    eventId: 31049,
    source: 'amazon',
    eventType: 'transaction',
    description: 'Waveshare CM5 Mini Base Board',
    date: '2026-01-29',
    amount: -31.49,
    orderIds: ['113-1234567-1234567'],
  ),
  expense: SuggestedExpense(
    id: 2669,
    name: 'Raspberry Pi base board',
    companyName: 'Amazon',
  ),
  tags: [
    SuggestedTag(
      system: 'Spending Category',
      path: ['Shopping', 'Electronics'],
    ),
  ],
  products: [
    SuggestedProduct(
      id: null,
      name: 'Waveshare CM5 Mini Base Board',
      quantity: 1,
      unit: 'item',
      price: 28.99,
      imageUrl: null,
      maker: SuggestedCompany(id: null, name: 'Waveshare'),
    ),
  ],
);
