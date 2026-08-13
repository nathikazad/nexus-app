@Tags(['unit'])
library;

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:nx_db/goals.dart';

const _monthResponse = '''
{
  "month_start": "2026-04-01",
  "items": [
    {
      "id": 101,
      "label": "Wake up before 7am",
      "cadence": "daily",
      "model_type": "Sleep",
      "filter": null,
      "selected_attribute": "end_time",
      "aggregation": "count",
      "metric": null,
      "target": { "op": ">=", "value": 1 },
      "daily_state": [
        { "date": "2026-04-01", "state": "hit" },
        { "date": "2026-04-02", "state": "miss" },
        { "date": "2026-04-03", "state": "pending" }
      ],
      "streak": {
        "is_active": true,
        "current_period_hit": true,
        "current": { "streak_count": 3, "first_period": "2026-04-01", "last_period": "2026-04-03" },
        "max": { "streak_count": 3, "first_period": "2026-04-01", "last_period": "2026-04-03" }
      },
      "meta": null
    }
  ]
}
''';

void main() {
  test('ActionGoalMonthResponse fromJson map', () {
    final m = json.decode(_monthResponse) as Map<String, dynamic>;
    final w = ActionGoalMonthResponse.fromJson(m);
    expect(w.monthStart, DateTime.parse('2026-04-01'));
    expect(w.items.length, 1);
    expect(w.items.first.id, 101);
    expect(w.items.first.dailyState.length, 3);
    expect(w.items.first.dailyState[1].state, GoalDayState.miss);
  });

  test('ActionGoalMonthResponse fromJson string (PostGraphile)', () {
    final w = parseGetActionGoalsMonthResult(
      _monthResponse,
      monthStart: DateTime.parse('2026-04-01'),
    );
    expect(w.items.first.label, 'Wake up before 7am');
  });
}
