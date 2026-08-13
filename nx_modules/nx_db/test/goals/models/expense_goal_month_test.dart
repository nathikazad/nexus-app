@Tags(['unit'])
library;

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:nx_db/goals.dart';
import 'package:test/test.dart' show Tags;

const _month = r'''
{
  "month_start": "2026-04-01",
  "items": [
    {
      "id": 301,
      "label": "Restaurants ≤ $300 / month",
      "cadence": "monthly",
      "model_type": "Expense",
      "filter": {
        "tag_filters": [
          {"system": "Category", "node": "Restaurants", "include_descendants": true}
        ]
      },
      "selected_attribute": "created_at",
      "aggregation": "sum",
      "metric": "cost",
      "target": { "op": "<=", "value": 300 },
      "meta": null,
      "period_value": 207
    }
  ]
}
''';

void main() {
  test('ExpenseGoalMonthResponse fromJson', () {
    final w = ExpenseGoalMonthResponse.fromJson(
      json.decode(_month) as Map<String, dynamic>,
    );
    expect(w.monthStart, DateTime.parse('2026-04-01'));
    expect(w.items.length, 1);
    expect(w.items.first.id, 301);
    expect(w.items.first.metric, 'cost');
    expect(w.items.first.periodValue, 207);
    expect(w.items.first.target.op, '<=');
  });

  test('parseGetExpenseGoalsMonthResult null returns empty for month', () {
    final w = parseGetExpenseGoalsMonthResult(
      null,
      monthStart: DateTime.parse('2026-04-01'),
    );
    expect(w.items, isEmpty);
  });
}
