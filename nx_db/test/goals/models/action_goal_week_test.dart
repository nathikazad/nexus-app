@Tags(['unit'])
library;

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:nx_db/goals.dart';
import 'package:test/test.dart' show Tags;

const _weekResponse = '''
{
  "week_start": "2026-04-20",
  "items": [
    {
      "id": 101,
      "label": "Wake up before 7am",
      "cadence": "daily",
      "model_type": "Sleep",
      "filter": {
        "filters": [{"key": "end_time", "op": "<=", "value": "07:00:00"}]
      },
      "selected_attribute": "end_time",
      "aggregation": "count",
      "metric": null,
      "target": { "op": ">=", "value": 1 },
      "daily_state": [
        { "date": "2026-04-20", "state": "hit"     },
        { "date": "2026-04-21", "state": "hit"     },
        { "date": "2026-04-22", "state": "miss"    },
        { "date": "2026-04-23", "state": "hit"     },
        { "date": "2026-04-24", "state": "hit"     },
        { "date": "2026-04-25", "state": "hit"     },
        { "date": "2026-04-26", "state": "pending" }
      ],
      "streak": {
        "is_active": true, "current_period_hit": true,
        "current": { "streak_count": 3, "first_period": "2026-04-23", "last_period": "2026-04-25" },
        "max":     { "streak_count": 12, "first_period": "2026-02-02", "last_period": "2026-02-13" }
      },
      "meta": null
    }
  ]
}
''';

void main() {
  test('ActionGoalWeekResponse fromJson map', () {
    final m = json.decode(_weekResponse) as Map<String, dynamic>;
    final w = ActionGoalWeekResponse.fromJson(m);
    expect(w.weekStart, DateTime.parse('2026-04-20'));
    expect(w.items.length, 1);
    expect(w.items.first.id, 101);
    expect(w.items.first.dailyState.length, 7);
    expect(w.items.first.dailyState.last.state, GoalDayState.pending);
    expect(w.items.first.streak.isActive, isTrue);
  });

  test('ActionGoalWeekResponse fromJson string (PostGraphile)', () {
    final w = parseGetActionGoalsWeekResult(
      _weekResponse,
      weekStart: DateTime.parse('2026-04-20'),
    );
    expect(w.items.first.label, 'Wake up before 7am');
  });

  test('ActionGoalMeta preferred_slots with hit', () {
    const metaJson = '''
    {
      "preferred_slots": [
        { "dow": "Mon", "start_time": "12:30", "duration_min": 60, "hit": true  },
        { "dow": "Wed", "start_time": "12:30", "duration_min": 60, "hit": false }
      ],
      "auto_generate_tasks": true
    }
    ''';
    final meta = ActionGoalMeta.fromJson(
      json.decode(metaJson) as Map<String, dynamic>,
    );
    expect(meta.preferredSlots?.length, 2);
    expect(meta.preferredSlots![0].hit, isTrue);
    expect(meta.preferredSlots![1].hit, isFalse);
  });
}
