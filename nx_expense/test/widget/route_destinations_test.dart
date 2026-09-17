import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nx_expense/data/providers.dart';
import 'package:nx_expense/features/expense/expense_list_page.dart';
import 'package:nx_expense/router.dart';

void main() {
  testWidgets(
    'scoped routes retain encoded labels, date ranges, and exact tag selection',
    (tester) async {
      late ProviderScope destination;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              destination =
                  buildExpenseDestination(
                        context,
                        Uri.parse(
                          '/expenses/by-tag/Work/50%25%20%2F%20Parts?includeDescendants=false&start=2026-09-06&end=2026-09-16',
                        ),
                      )
                      as ProviderScope;
              return const SizedBox();
            },
          ),
        ),
      );
      final list = destination.child as ExpenseListScreen;
      expect(list.title, '50% / Parts');
      expect(list.initialFilter!.tagFilters!.single, {
        'system': 'Work',
        'node': '50% / Parts',
        'include_descendants': false,
      });
      final container = ProviderContainer(overrides: destination.overrides);
      addTearDown(container.dispose);
      expect(
        container.read(expenseDateRangeProvider),
        DateTimeRange(start: DateTime(2026, 9, 6), end: DateTime(2026, 9, 16)),
      );
    },
  );
  testWidgets('date deep links filter the day even without query parameters', (
    tester,
  ) async {
    late ProviderScope destination;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            destination =
                buildExpenseDestination(
                      context,
                      Uri.parse('/expenses/by-date/2026-09-15'),
                    )
                    as ProviderScope;
            return const SizedBox();
          },
        ),
      ),
    );
    final container = ProviderContainer(overrides: destination.overrides);
    addTearDown(container.dispose);
    expect(
      container.read(expenseDateRangeProvider),
      DateTimeRange(start: DateTime(2026, 9, 15), end: DateTime(2026, 9, 15)),
    );
  });
}
