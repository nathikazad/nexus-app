import 'package:nx_time/domain/goals/goal_repository.dart';
import 'package:nx_time/domain/goals/goal.dart';
import 'package:nx_time/domain/goals/action_goal.dart';
import 'package:nx_time/domain/goals/expense_goal.dart';
import 'package:nx_time/data/domains/domain_workspace.dart';

class MultiGoalRepository implements GoalRepository {
  MultiGoalRepository(this.w);
  final DomainWorkspace w;
  @override
  Future<ActionGoalsWeek> getActionGoalsWeek({
    required DateTime weekStart,
    int? goalId,
  }) async {
    final ids = goalId == null ? w.selectedIds : {await w.owner(goalId)};
    final rows = await Future.wait(
      ids.map((id) async {
        final r = await w
            .goals(id)
            .getActionGoalsWeek(weekStart: weekStart, goalId: goalId);
        w.remember(id, r.items.map((g) => g.id));
        return r;
      }),
    );
    return ActionGoalsWeek(
      weekStart: weekStart,
      items: rows.expand((r) => r.items).toList(),
    );
  }

  @override
  Future<ActionGoalsMonth> getActionGoalsMonth({
    required DateTime monthStart,
    int? goalId,
  }) async {
    final ids = goalId == null ? w.selectedIds : {await w.owner(goalId)};
    final rows = await Future.wait(
      ids.map((id) async {
        final r = await w
            .goals(id)
            .getActionGoalsMonth(monthStart: monthStart, goalId: goalId);
        w.remember(id, r.items.map((g) => g.id));
        return r;
      }),
    );
    return ActionGoalsMonth(
      monthStart: monthStart,
      items: rows.expand((r) => r.items).toList(),
    );
  }

  @override
  Future<ActionGoalsMonthScore> getActionGoalsMonthScore({
    required DateTime monthStart,
    int? goalId,
  }) async {
    final ids = goalId == null ? w.selectedIds : {await w.owner(goalId)};
    final rows = await Future.wait(
      ids.map(
        (id) => w
            .goals(id)
            .getActionGoalsMonthScore(monthStart: monthStart, goalId: goalId),
      ),
    );
    final days = <DateTime, List<ActionGoalMonthScoreDay>>{};
    for (final r in rows) {
      for (final d in r.days) {
        days.putIfAbsent(d.date, () => []).add(d);
      }
    }
    final merged = days.entries.map((e) {
      final hit = e.value.fold<int>(0, (a, b) => a + b.hit),
          total = e.value.fold<int>(0, (a, b) => a + b.total);
      return ActionGoalMonthScoreDay(
        date: e.key,
        hit: hit,
        total: total,
        ratio: total == 0 ? null : hit / total,
        future: e.value.every((d) => d.future),
      );
    }).toList()..sort((a, b) => a.date.compareTo(b.date));
    final hit = rows.fold<int>(0, (a, b) => a + b.consistency.hit),
        total = rows.fold<int>(0, (a, b) => a + b.consistency.total);
    return ActionGoalsMonthScore(
      monthStart: monthStart,
      consistency: ActionGoalMonthConsistency(
        hit: hit,
        total: total,
        ratio: total == 0 ? null : hit / total,
      ),
      days: merged,
    );
  }

  @override
  Future<ActionGoalsTrend> getActionGoalsTrend({
    required int goalId,
    required int weeks,
  }) async => w
      .goals(await w.owner(goalId))
      .getActionGoalsTrend(goalId: goalId, weeks: weeks);
  @override
  Future<ExpenseGoalsMonth> getExpenseGoalsMonth({
    required DateTime monthStart,
    int? goalId,
  }) async {
    final ids = goalId == null ? w.selectedIds : {await w.owner(goalId)};
    final rows = await Future.wait(
      ids.map((id) async {
        final r = await w
            .goals(id)
            .getExpenseGoalsMonth(monthStart: monthStart, goalId: goalId);
        w.remember(id, r.items.map((g) => g.id));
        return r;
      }),
    );
    return ExpenseGoalsMonth(
      monthStart: monthStart,
      items: rows.expand((r) => r.items).toList(),
    );
  }

  @override
  Future<Goal?> getById(int id) async => w.goals(await w.owner(id)).getById(id);
  @override
  Future<int> create(Goal goal) async =>
      throw StateError('Choose a destination domain');
  @override
  Future<int> update(Goal goal) async =>
      w.goals(await w.owner(goal.id!, write: true)).update(goal);
  @override
  Future<void> delete(int id) async =>
      w.goals(await w.owner(id, write: true)).delete(id);
}
