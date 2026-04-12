@Tags(['integration'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nx_db/nx_db.dart';
import 'package:nx_expense/expense_schema.dart';
import 'package:nx_expense/providers/expense_providers.dart';
import 'package:test/test.dart' show Tags;

import 'support/integration_auth.dart';

void main() {
  group('I9 integration (live GraphQL)', () {
    test(
      'I9.1 Expense schema load — attributes non-empty',
      () async {
        final container = ProviderContainer(
          overrides: expenseIntegrationOverrides,
        );
        addTearDown(container.dispose);

        await container.read(authProvider.future);
        final mt = await container.read(expenseSchemaProvider.future);
        expect(mt.name, kExpenseModelTypeName);
        expect(mt.attributes, isNotNull);
        expect(mt.attributes, isNotEmpty);
      },
      skip: runExpenseIntegration ? null : kExpenseIntegrationSkipReason,
    );

    test(
      'I9.2 Tag systems present',
      () async {
        final container = ProviderContainer(
          overrides: expenseIntegrationOverrides,
        );
        addTearDown(container.dispose);

        await container.read(authProvider.future);
        final mt = await container.read(expenseSchemaProvider.future);
        expect(mt.tagSystems, isNotNull);
        expect(mt.tagSystems!.length, greaterThanOrEqualTo(1));
      },
      skip: runExpenseIntegration ? null : kExpenseIntegrationSkipReason,
    );

    test(
      'I9.3 List expenses — seed DB returns rows',
      () async {
        final container = ProviderContainer(
          overrides: expenseIntegrationOverrides,
        );
        addTearDown(container.dispose);

        await container.read(authProvider.future);
        final list = await container.read(
          expenseListProvider((
            filter: null,
            dateRange: DateTimeRange(
              start: DateTime(2000, 1, 1),
              end: DateTime(2030, 12, 31),
            ),
          )).future,
        );
        expect(list.length, greaterThan(0));
      },
      skip: runExpenseIntegration ? null : kExpenseIntegrationSkipReason,
    );
  });
}
