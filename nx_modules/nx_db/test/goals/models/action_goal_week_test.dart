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
  test('schedule and restriction details survive wire serialization', () {
    final m = json.decode(_weekResponse) as Map<String, dynamic>;
    final item = (m['items'] as List).first as Map<String, dynamic>;
    item['evaluation'] = 'restrictions';
    item['restrictions'] = {
      'not_before': '21:00',
      'max_duration_seconds': 1800,
    };
    item['daily_state'] = [
      {
        'date': '2026-04-20',
        'state': 'miss',
        'start_met': true,
        'end_met': false,
        'both_met': false,
        'windows': [
          {'entry_index': 1, 'actual_start': '2026-04-20T22:00:00Z'},
        ],
        'sessions': [
          {
            'action_id': 10,
            'duration_met': true,
            'not_before_met': false,
            'met': false,
          },
        ],
      },
    ];
    final parsed = ActionGoalWeekResponse.fromJson(m).items.single;
    final copy = ActionGoalWeekItem.fromJson(parsed.toJson());
    expect(copy.evaluation, 'restrictions');
    expect(copy.restrictions, item['restrictions']);
    expect(copy.dailyState.single.startMet, isTrue);
    expect(copy.dailyState.single.endMet, isFalse);
    expect(
      copy.dailyState.single.windows.single['actual_start'],
      '2026-04-20T22:00:00Z',
    );
    expect(copy.dailyState.single.sessions.single['not_before_met'], isFalse);
  });
  test('ActionGoalWeekResponse fromJson map', () {
    final m = json.decode(_weekResponse) as Map<String, dynamic>;
    final w = ActionGoalWeekResponse.fromJson(m);
    expect(w.weekStart, DateTime.parse('2026-04-20'));
    expect(w.items.length, 1);
    expect(w.items.first.id, 101);
    expect(w.items.first.evaluation, 'aggregate');
    expect(w.items.first.dailyState.first.startMet, isNull);
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

  test('ActionGoalSchedule grouped days', () {
    const metaJson = '''
    {
      "entries": [{"days":["monday", "tuesday"], "start_time":"07:30", "end_time":"08:00"}, {"days":["monday"], "start_time":"19:00", "end_time":"20:00"}]
    }
    ''';
    final meta = ActionGoalSchedule.fromJson(
      json.decode(metaJson) as Map<String, dynamic>,
    );
    expect(meta.days, ['monday', 'tuesday']);
  });
}
