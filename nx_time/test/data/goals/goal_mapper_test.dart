import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:nx_db/goals.dart' as nx;
import 'package:nx_db/kgql.dart';
import 'package:nx_time/data/goals/goal_attr_keys.dart';
import 'package:nx_time/data/goals/goal_mapper.dart';
import 'package:nx_time/domain/goals/goal.dart';
import 'package:nx_time/domain/goals/goal_cadence.dart';
import 'package:nx_time/domain/goals/goal_selected_attribute.dart';
import 'package:nx_time/domain/goals/goal_threshold.dart';

const _trendEmpty = r'{ "buckets": [] }';

const _trendFull = r'''
{
  "goal_id": 101,
  "cadence": "daily",
  "weeks": 8,
  "buckets": [
    { "period_start": "2026-04-20", "successes": 5, "expected": 7, "hit": false }
  ]
}
''';

void main() {
  test('action week maps', () {
    const raw = r'''
    {
      "week_start": "2026-04-20",
      "items": [
        {
          "id": 1,
          "label": "L",
          "cadence": "daily",
          "model_type": "Sleep",
          "filter": null,
          "selected_attribute": "end_time",
          "aggregation": "count",
          "metric": null,
          "target": { "op": ">=", "value": 1 },
          "daily_state": [
            { "date": "2026-04-20", "state": "hit" }
          ],
          "streak": {
            "is_active": true,
            "current_period_hit": true,
            "current": { "streak_count": 1, "first_period": "2026-04-20", "last_period": "2026-04-20" },
            "max": { "streak_count": 1, "first_period": "2026-04-20", "last_period": "2026-04-20" }
          },
          "meta": null
        }
      ]
    }
    ''';
    final w = nx.ActionGoalWeekResponse.fromJson(
      json.decode(raw) as Map<String, dynamic>,
    );
    final d = actionGoalsWeekFromWire(w);
    expect(d.items.first.cadence, GoalCadence.daily);
    expect(d.items.first.target.op, GoalThresholdOp.gte);
  });

  test('trend: empty server envelope maps to emptyEnvelope', () {
    final wire = nx.parseGetActionGoalsTrendResult(_trendEmpty);
    final d = actionGoalsTrendFromWire(
      wire,
      requestedGoalId: 999,
      requestedWeeks: 3,
    );
    expect(d.goalId, 999);
    expect(d.weeks, 3);
    expect(d.cadence, isNull);
    expect(d.buckets, isEmpty);
  });

  test('trend: full response maps', () {
    final wire = nx.parseGetActionGoalsTrendResult(_trendFull);
    final d = actionGoalsTrendFromWire(
      wire,
      requestedGoalId: 101,
      requestedWeeks: 8,
    );
    expect(d.goalId, 101);
    expect(d.cadence, GoalCadence.daily);
    expect(d.weeks, 8);
    expect(d.buckets.length, 1);
    expect(d.buckets.first.hit, isFalse);
  });

  test('action month maps', () {
    const raw = r'''
    {
      "month_start": "2026-04-01",
      "items": [
        {
          "id": 1,
          "label": "L",
          "cadence": "daily",
          "model_type": "Sleep",
          "filter": null,
          "selected_attribute": "end_time",
          "aggregation": "count",
          "metric": null,
          "target": { "op": ">=", "value": 1 },
          "daily_state": [
            { "date": "2026-04-01", "state": "hit" },
            { "date": "2026-04-02", "state": "miss" }
          ],
          "streak": {
            "is_active": true,
            "current_period_hit": true,
            "current": { "streak_count": 1, "first_period": "2026-04-01", "last_period": "2026-04-01" },
            "max": { "streak_count": 1, "first_period": "2026-04-01", "last_period": "2026-04-01" }
          },
          "meta": null
        }
      ]
    }
    ''';
    final w = nx.ActionGoalMonthResponse.fromJson(
      json.decode(raw) as Map<String, dynamic>,
    );
    final d = actionGoalsMonthFromWire(w);
    expect(d.monthStart, DateTime(2026, 4));
    expect(d.items.first.dailyState.length, 2);
    expect(d.items.first.cadence, GoalCadence.daily);
  });

  test('expense month maps', () {
    const raw = r'''
    {
      "month_start": "2026-04-01",
      "items": [
        {
          "id": 301,
          "label": "R",
          "cadence": "monthly",
          "model_type": "Expense",
          "filter": null,
          "selected_attribute": "created_at",
          "aggregation": "sum",
          "metric": "cost",
          "target": { "op": "<=", "value": 300 },
          "period_value": 207
        }
      ]
    }
    ''';
    final w = nx.ExpenseGoalMonthResponse.fromJson(
      json.decode(raw) as Map<String, dynamic>,
    );
    final d = expenseGoalsMonthFromWire(w);
    expect(d.items.first.periodValue, 207);
    expect(d.items.first.target.op, GoalThresholdOp.lte);
  });

  test('setModelRequestForCreateGoal: daily sets due days meta', () {
    final g = Goal(
      label: 'G',
      cadence: GoalCadence.daily,
      actionModelTypeName: 'Yoga',
      selectedAttribute: GoalSelectedAttribute.count,
      op: GoalThresholdOp.gte,
      thresholdValue: 1,
      dueDays: const [0, 1, 2, 3, 4, 5],
    );
    final req = setModelRequestForCreateGoal(g);
    expect(req.modelType, 'Goal');
    final attrs = req.attributes;
    expect(attrs, isNotNull);
    final map = {for (final a in attrs!) a.key: a.value};
    expect(map[kGoalAttrThresholdValue], 1);
    final meta = map[kGoalAttrMeta] as Map<String, dynamic>?;
    expect(meta!['due_days'], ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat']);
  });

  test('goalFromModel round-trip for duration', () {
    final g = Goal(
      label: 'Sleep more',
      cadence: GoalCadence.daily,
      actionModelTypeName: 'Sleep',
      selectedAttribute: GoalSelectedAttribute.duration,
      op: GoalThresholdOp.gte,
      thresholdValue: 8,
    );
    final req = setModelRequestForCreateGoal(g);
    final attrMap = <String, dynamic>{
      for (final a in req.attributes ?? const <SetModelAttribute>[])
        a.key: a.value,
    };
    final m2 = Model(
      id: 42,
      name: g.label,
      modelTypeId: 1,
      attributes: attrMap,
    );
    final back = goalFromModel(m2);
    expect(back.selectedAttribute, GoalSelectedAttribute.duration);
    expect(back.thresholdValue, closeTo(8.0, 0.001));
  });
}
