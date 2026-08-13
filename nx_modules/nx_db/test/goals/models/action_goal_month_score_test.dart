@Tags(['unit'])
library;

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:nx_db/goals.dart';

const _scoreResponse = '''
{
  "month_start": "2026-04-01",
  "consistency": { "hit": 3, "total": 6, "ratio": 0.5 },
  "days": [
    { "date": "2026-04-01", "hit": 0, "total": 2, "ratio": 0, "future": false },
    { "date": "2026-04-02", "hit": 1, "total": 2, "ratio": 0.5, "future": false },
    { "date": "2026-04-03", "hit": 2, "total": 2, "ratio": 1, "future": false },
    { "date": "2026-04-04", "hit": 0, "total": 0, "ratio": null, "future": true }
  ]
}
''';

void main() {
  test('ActionGoalMonthScoreResponse fromJson map', () {
    final m = json.decode(_scoreResponse) as Map<String, dynamic>;
    final r = ActionGoalMonthScoreResponse.fromJson(m);
    expect(r.monthStart, DateTime.parse('2026-04-01'));
    expect(r.consistency.hit, 3);
    expect(r.consistency.total, 6);
    expect(r.consistency.ratio, 0.5);
    expect(r.days.length, 4);
    expect(r.days[1].hit, 1);
    expect(r.days[1].total, 2);
    expect(r.days[1].ratio, 0.5);
    expect(r.days[3].future, isTrue);
    expect(r.days[3].ratio, isNull);
  });

  test('ActionGoalMonthScoreResponse fromJson string (PostGraphile)', () {
    final r = parseGetActionGoalsMonthScoreResult(
      _scoreResponse,
      monthStart: DateTime.parse('2026-04-01'),
    );
    expect(r.consistency.ratio, 0.5);
    expect(r.days[2].ratio, 1);
  });

  test('ActionGoalMonthScoreResponse defaults missing consistency', () {
    final r = ActionGoalMonthScoreResponse.fromJson({
      'month_start': '2026-04-01',
      'days': <dynamic>[],
    });
    expect(r.consistency.hit, 0);
    expect(r.consistency.total, 0);
    expect(r.consistency.ratio, isNull);
  });
}
