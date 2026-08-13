@Tags(['unit'])
library;

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:nx_db/goals.dart';
import 'package:test/test.dart' show Tags;

const _trendFull = '''
{
  "goal_id": 101,
  "cadence": "daily",
  "weeks": 8,
  "buckets": [
    { "period_start": "2026-03-02", "successes": 4, "expected": 7, "hit": false },
    { "period_start": "2026-04-20", "successes": 5, "expected": 7, "hit": false }
  ]
}
''';

void main() {
  test('ActionGoalTrendResponse full envelope', () {
    final w = ActionGoalTrendResponse.fromJson(
      json.decode(_trendFull) as Map<String, dynamic>,
    );
    expect(w.goalId, 101);
    expect(w.cadence, 'daily');
    expect(w.weeks, 8);
    expect(w.buckets.length, 2);
    expect(w.buckets.first.periodStart, DateTime.parse('2026-03-02'));
    expect(w.buckets.first.hit, isFalse);
  });

  test('ActionGoalTrendResponse buckets-only empty (not found)', () {
    const raw = '{ "buckets": [] }';
    final w = parseGetActionGoalsTrendResult(raw);
    expect(w.goalId, isNull);
    expect(w.cadence, isNull);
    expect(w.weeks, isNull);
    expect(w.buckets, isEmpty);
  });

  test('parse from string', () {
    final w = parseGetActionGoalsTrendResult(_trendFull);
    expect(w.goalId, 101);
  });
}
