import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nx_db/goals.dart' as wire;
import 'package:nx_time/data/goals/goal_mapper.dart';
import 'package:nx_time/features/goals/goal_detail/consumption_goal_results.dart';

Map<String, dynamic> item({
  bool monthly = true,
  int value = 7,
  String state = 'pending',
}) => {
  'id': 1,
  'label': monthly ? 'Junk food' : 'Protein shake',
  'model_type': 'Consumption',
  'cadence': monthly ? 'monthly' : 'daily',
  'evaluation': 'aggregate',
  'selected_attribute': 'start_time',
  'aggregation': 'count',
  'target': {'op': monthly ? '<=' : '>=', 'value': monthly ? 7 : 2},
  'filter': {
    'relation_filters': [
      {
        'model_type': 'Consumable',
        'model_ids': [1060],
      },
    ],
  },
  'daily_state': monthly
      ? []
      : [
          {'date': '2026-06-01', 'state': state, 'value': value},
        ],
  'month_summary': monthly
      ? {
          'period_start': '2026-06-01',
          'value': value,
          'state': state,
          'met': value <= 7,
        }
      : null,
};

void main() {
  test(
    'monthly summary and daily counts survive cache serialization and mapping',
    () {
      for (final monthly in [true, false]) {
        final response = wire.ActionGoalMonthResponse.fromJson({
          'month_start': '2026-06-01',
          'items': [item(monthly: monthly)],
        });
        final cached = wire.ActionGoalMonthResponse.fromJson(response.toJson());
        final goal = actionGoalsMonthFromWire(cached).items.single;
        if (monthly) {
          expect(goal.monthSummary?['value'], 7);
          expect(goal.monthSummary?['state'], 'pending');
          expect(goal.dailyState, isEmpty);
        } else {
          expect(goal.dailyState.single.value, 7);
        }
        expect(goal.filter?['relation_filters'], isNotEmpty);
      }
    },
  );
  for (final entry in [
    (7, 'pending', 'Within limit · month in progress'),
    (7, 'hit', 'Met'),
    (8, 'miss', 'Limit exceeded'),
    (0, 'hit', 'Met'),
  ]) {
    testWidgets('monthly count ${entry.$1} ${entry.$2}', (tester) async {
      final goal = actionGoalsMonthFromWire(
        wire.ActionGoalMonthResponse.fromJson({
          'month_start': '2026-06-01',
          'items': [item(value: entry.$1, state: entry.$2)],
        }),
      ).items.single;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: MonthlyGoalProgress(item: goal)),
        ),
      );
      expect(find.text('${entry.$1} of 7'), findsOneWidget);
      expect(find.text(entry.$3), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets(
    'protein display uses server count and target, not unfiltered meals',
    (tester) async {
      final goal = actionGoalsMonthFromWire(
        wire.ActionGoalMonthResponse.fromJson({
          'month_start': '2026-06-01',
          'items': [item(monthly: false, value: 1, state: 'miss')],
        }),
      ).items.single;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: ConsumptionGoalResults(item: goal)),
        ),
      );
      expect(find.text('1 of 2'), findsOneWidget);
      expect(find.text('Mon, Jun 1'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
