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

DateTimeRange _wideExpenseRange() {
  return DateTimeRange(
    start: DateTime(2000, 1, 1),
    end: DateTime(2030, 12, 31),
  );
}

/// Assertions aligned with [servers/pgdb/docs/llm-reference/seed-data.md]
/// (`setup_model_types`, `setup_expense_tag_systems`, demo Expense rows).
void _collectTagNodeNames(TagNode n, Set<String> out) {
  out.add(n.name);
  for (final c in n.children ?? const <TagNode>[]) {
    _collectTagNodeNames(c, out);
  }
}

void main() {
  group('Seed schema (seed-data.md) — Expense app', () {
    test('Expense type: cost, Company relation, Category/Judgment/Essentiality', () async {
      final container = ProviderContainer(
        overrides: expenseIntegrationOverrides,
      );
      addTearDown(container.dispose);

      await container.read(authProvider.future);
      final mt = await container.read(expenseSchemaProvider.future);

      expect(mt.name, kExpenseModelTypeName);
      final keys = mt.attributes?.map((a) => a.key).whereType<String>().toSet() ?? {};
      expect(keys, contains('cost'));

      final targets = allRelationTargetTypeNames(mt);
      expect(targets, contains('Company'));

      for (final name in ['Category', 'Judgment', 'Essentiality']) {
        expect(tagSystemByName(mt, name), isNotNull, reason: 'Tag system $name');
      }
    }, skip: runExpenseIntegration ? null : kExpenseIntegrationSkipReason);

    test('Category tag tree includes seed root nodes', () async {
      final container = ProviderContainer(
        overrides: expenseIntegrationOverrides,
      );
      addTearDown(container.dispose);

      await container.read(authProvider.future);
      final mt = await container.read(expenseSchemaProvider.future);

      final category = tagSystemByName(mt, 'Category');
      expect(category, isNotNull);
      final names = <String>{};
      for (final node in category!.nodes) {
        _collectTagNodeNames(node, names);
      }
      for (final root in ['Food', 'Travel', 'Business', 'Entertainment']) {
        expect(names, contains(root));
      }
    }, skip: runExpenseIntegration ? null : kExpenseIntegrationSkipReason);

    test('expense_schema helpers: primary amount is cost', () async {
      final container = ProviderContainer(
        overrides: expenseIntegrationOverrides,
      );
      addTearDown(container.dispose);

      await container.read(authProvider.future);
      final mt = await container.read(expenseSchemaProvider.future);

      expect(primaryNumberAttributeKey(mt), 'cost');
    }, skip: runExpenseIntegration ? null : kExpenseIntegrationSkipReason);

    test('expenseSummaryProvider: count > 0 and sum over cost', () async {
      final container = ProviderContainer(
        overrides: expenseIntegrationOverrides,
      );
      addTearDown(container.dispose);

      await container.read(authProvider.future);
      final summary = await container.read(expenseSummaryProvider.future);

      expect(summary.count, greaterThan(0));
      expect(summary.sumTotal, isNotNull);
      expect(summary.sumTotal!, greaterThan(0));
    }, skip: runExpenseIntegration ? null : kExpenseIntegrationSkipReason);

    test('demo expense names from seed table appear in list', () async {
      final container = ProviderContainer(
        overrides: expenseIntegrationOverrides,
      );
      addTearDown(container.dispose);

      await container.read(authProvider.future);
      final list = await container.read(
        expenseListProvider((filter: null, dateRange: _wideExpenseRange())).future,
      );
      final names = list.map((m) => m.name).toSet();

      // seed-data.md § Expenses (demo graph)
      const expectedAnyOf = [
        'Coffee Meeting',
        'Hotel Stay',
        'Software License',
        'Team Lunch',
      ];
      final matched = expectedAnyOf.where(names.contains).length;
      expect(
        matched,
        greaterThanOrEqualTo(2),
        reason: 'Expected at least two known demo rows; got names: $names',
      );
    }, skip: runExpenseIntegration ? null : kExpenseIntegrationSkipReason);

    test('at least one expense has tag assignments (struct includes tags)', () async {
      final container = ProviderContainer(
        overrides: expenseIntegrationOverrides,
      );
      addTearDown(container.dispose);

      await container.read(authProvider.future);
      final list = await container.read(
        expenseListProvider((filter: null, dateRange: _wideExpenseRange())).future,
      );

      var anyTags = false;
      for (final m in list) {
        final t = m.tags;
        if (t != null && t.isNotEmpty) {
          anyTags = true;
          break;
        }
      }
      expect(
        anyTags,
        isTrue,
        reason: 'Seed assigns Category/Judgment/Essentiality on demo expenses',
      );
    }, skip: runExpenseIntegration ? null : kExpenseIntegrationSkipReason);
  });
}
