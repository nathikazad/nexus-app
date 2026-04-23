// Goals live GraphQL — requires the same `CURRENT_DATE` as when you ran:
//   python admin_functions/reset_db.py --till-model-types --with-goals
// Re-seed the same day you run `RUN_NX_TIME_INTEGRATION=true flutter test` or results drift.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nx_db/auth.dart';
import 'package:nx_time/data/providers.dart';
import 'package:nx_time/domain/goals/goal_cadence.dart';
import 'package:nx_time/domain/goals/goal_day_state.dart';
import 'package:nx_time/domain/goals/goal_threshold.dart';

import '../_support/integration_auth.dart';

const _kActionGoalLabels = <String>[
  'Wake up before 7am',
  'Sleep by 11pm',
  'Sleep 8 hours',
  'Yoga every day',
  'Reading 1hr / day',
  'Gym 3x/week',
  'Language learning 3hrs / week',
  'Dancing 3hrs / week',
];

const _kDailyActionLabels = <String>{
  'Wake up before 7am',
  'Sleep by 11pm',
  'Sleep 8 hours',
  'Yoga every day',
  'Reading 1hr / day',
};

const _kWeeklyActionLabels = <String>{
  'Gym 3x/week',
  'Language learning 3hrs / week',
  'Dancing 3hrs / week',
};

DateTime _mondayOfLocalWeek(DateTime d) {
  final c = DateTime(d.year, d.month, d.day);
  return c.subtract(Duration(days: c.weekday - 1));
}

DateTime _firstOfMonthLocal(DateTime d) {
  return DateTime(d.year, d.month, 1);
}

void _expectContiguousLocalDays(List<GoalDailyState> dailyState) {
  expect(dailyState.length, 7);
  for (var i = 0; i < 6; i++) {
    final a = DateTime(
      dailyState[i].date.year,
      dailyState[i].date.month,
      dailyState[i].date.day,
    );
    final b = DateTime(
      dailyState[i + 1].date.year,
      dailyState[i + 1].date.month,
      dailyState[i + 1].date.day,
    );
    expect(b.difference(a).inDays, 1);
  }
}

void main() {
  group('nx_time goals (live GraphQL, goals seed)', () {
    test(
      'getActionGoalsWeek: week envelope, 8 active action goals, cadences, 7 days',
      () async {
        final container = ProviderContainer(overrides: timeIntegrationOverrides);
        addTearDown(container.dispose);

        await container.read(authProvider.future);
        final repo = container.read(goalRepositoryProvider);
        final now = DateTime.now();
        final monday = _mondayOfLocalWeek(now);

        final w = await repo.getActionGoalsWeek(weekStart: monday);
        final gotMonday = DateTime(
          w.weekStart.year,
          w.weekStart.month,
          w.weekStart.day,
        );
        expect(gotMonday, monday);
        expect(w.items.length, greaterThanOrEqualTo(8));

        final byLabel = {for (final i in w.items) i.label: i};
        for (final label in _kActionGoalLabels) {
          expect(byLabel, containsPair(label, isNotNull));
        }
        for (final item in w.items) {
          _expectContiguousLocalDays(item.dailyState);
        }
        for (final label in _kDailyActionLabels) {
          final it = byLabel[label]!;
          expect(it.cadence, GoalCadence.daily);
        }
        for (final label in _kWeeklyActionLabels) {
          final it = byLabel[label]!;
          expect(it.cadence, GoalCadence.weekly);
        }
      },
      tags: ['integration'],
      skip: runTimeIntegration ? null : kTimeIntegrationSkipReason,
    );

    test(
      'getActionGoalsWeek(goalId: gym): meta preferred_slots + auto_generate_tasks',
      () async {
        final container = ProviderContainer(overrides: timeIntegrationOverrides);
        addTearDown(container.dispose);

        await container.read(authProvider.future);
        final repo = container.read(goalRepositoryProvider);
        final monday = _mondayOfLocalWeek(DateTime.now());

        final all = await repo.getActionGoalsWeek(weekStart: monday);
        final gymItem = all.items.firstWhere((i) => i.label == 'Gym 3x/week');

        final one = await repo.getActionGoalsWeek(
          weekStart: monday,
          goalId: gymItem.id,
        );
        expect(one.items.length, 1);
        final g = one.items.first;
        expect(g.label, 'Gym 3x/week');
        final meta = g.meta;
        expect(meta, isNotNull);
        final slots = meta!.preferredSlots;
        expect(slots, isNotNull);
        expect(slots!.length, 3);
        final dows = slots.map((s) => s.dow).toSet();
        expect(dows, {'Mon', 'Wed', 'Fri'});
        for (final s in slots) {
          expect(s.startTime, '12:30');
          expect(s.durationMin, 60);
        }
        expect(meta.autoGenerateTasks, isTrue);
      },
      tags: ['integration'],
      skip: runTimeIntegration ? null : kTimeIntegrationSkipReason,
    );

    test(
      'getActionGoalsTrend: Yoga every day, 12 weekly buckets with values',
      () async {
        final container = ProviderContainer(overrides: timeIntegrationOverrides);
        addTearDown(container.dispose);

        await container.read(authProvider.future);
        final repo = container.read(goalRepositoryProvider);
        final monday = _mondayOfLocalWeek(DateTime.now());
        final all = await repo.getActionGoalsWeek(weekStart: monday);
        final yoga = all.items.firstWhere((i) => i.label == 'Yoga every day');

        final t = await repo.getActionGoalsTrend(goalId: yoga.id, weeks: 12);
        expect(t.goalId, yoga.id);
        expect(t.cadence, GoalCadence.daily);
        expect(t.weeks, 12);
        expect(t.buckets.length, 12);
        for (final b in t.buckets) {
          expect(
            b.periodStart.year * 10000 + b.periodStart.month * 100 + b.periodStart.day,
            greaterThan(0),
          );
        }
        for (final b in t.buckets) {
          expect(b.successes, isA<num>());
          expect(b.expected, isA<num>());
        }
      },
      tags: ['integration'],
      skip: runTimeIntegration ? null : kTimeIntegrationSkipReason,
    );

    test(
      'getExpenseGoalsMonth: 2 active caps, sums Restaurants 207 / Amazon 318',
      () async {
        final container = ProviderContainer(overrides: timeIntegrationOverrides);
        addTearDown(container.dispose);

        await container.read(authProvider.future);
        final repo = container.read(goalRepositoryProvider);
        final month = _firstOfMonthLocal(DateTime.now());

        final m = await repo.getExpenseGoalsMonth(monthStart: month);
        final gotMonth = DateTime(m.monthStart.year, m.monthStart.month, 1);
        expect(gotMonth, month);
        final labels = m.items.map((e) => e.label).toSet();
        expect(labels, containsAll(['Restaurants cap', 'Amazon cap']));
        expect(
          m.items.map((e) => e.label),
          isNot(contains('Inactive monthly')),
        );
        expect(m.items.length, 2);

        final r = m.items.firstWhere((i) => i.label == 'Restaurants cap');
        expect(r.target.op, GoalThresholdOp.lte);
        expect(r.target.value, 300);
        // 12+33+17+25+41+32+47 — `include_descendants` counts coffee + fast under Restaurants.
        expect(r.periodValue, 207);

        final a = m.items.firstWhere((i) => i.label == 'Amazon cap');
        expect(a.target.op, GoalThresholdOp.lte);
        expect(a.target.value, 500);
        expect(a.periodValue, 318);
      },
      tags: ['integration'],
      skip: runTimeIntegration ? null : kTimeIntegrationSkipReason,
    );

    test(
      'getExpenseGoalsMonth(goalId:): single Restaurants cap passthrough',
      () async {
        final container = ProviderContainer(overrides: timeIntegrationOverrides);
        addTearDown(container.dispose);

        await container.read(authProvider.future);
        final repo = container.read(goalRepositoryProvider);
        final month = _firstOfMonthLocal(DateTime.now());

        final all = await repo.getExpenseGoalsMonth(monthStart: month);
        final restaurantsId = all.items
            .firstWhere((i) => i.label == 'Restaurants cap')
            .id;

        final one = await repo.getExpenseGoalsMonth(
          monthStart: month,
          goalId: restaurantsId,
        );
        expect(one.items.length, 1);
        final r = one.items.first;
        expect(r.id, restaurantsId);
        expect(r.label, 'Restaurants cap');
        expect(r.periodValue, 207);
      },
      tags: ['integration'],
      skip: runTimeIntegration ? null : kTimeIntegrationSkipReason,
    );
  });
}
