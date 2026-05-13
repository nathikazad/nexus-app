import 'package:nx_time/domain/goals/action_goal.dart';
import 'package:nx_time/domain/goals/expense_goal.dart';
import 'package:nx_time/domain/goals/goal.dart';
import 'package:nx_time/domain/goals/goal_repository.dart';

/// In-memory [GoalRepository] for tests.
class FakeGoalRepository implements GoalRepository {
  FakeGoalRepository({this.delay = Duration.zero, ActionGoalsWeek? actionWeek})
    : actionWeek =
          actionWeek ??
          ActionGoalsWeek(weekStart: DateTime(2000, 1, 3), items: const []);

  final Duration delay;
  ActionGoalsWeek actionWeek;
  int nextId = 1;
  final Map<int, Goal> _goals = {};

  /// Set by [create] for widget / integration tests.
  Goal? lastCreated;

  /// Set by [update] for widget / integration tests.
  Goal? lastUpdated;

  @override
  Future<ActionGoalsWeek> getActionGoalsWeek({
    required DateTime weekStart,
    int? goalId,
  }) async {
    if (delay > Duration.zero) {
      await Future<void>.delayed(delay);
    }
    return actionWeek;
  }

  @override
  Future<ActionGoalsTrend> getActionGoalsTrend({
    required int goalId,
    required int weeks,
  }) {
    return Future.value(
      ActionGoalsTrend.emptyEnvelope(
        requestedGoalId: goalId,
        requestedWeeks: weeks,
      ),
    );
  }

  @override
  Future<ExpenseGoalsMonth> getExpenseGoalsMonth({
    required DateTime monthStart,
    int? goalId,
  }) async {
    if (delay > Duration.zero) {
      await Future<void>.delayed(delay);
    }
    return ExpenseGoalsMonth(monthStart: monthStart, items: const []);
  }

  @override
  Future<Goal?> getById(int id) async {
    if (delay > Duration.zero) {
      await Future<void>.delayed(delay);
    }
    return _goals[id];
  }

  @override
  Future<int> create(Goal goal) async {
    if (delay > Duration.zero) {
      await Future<void>.delayed(delay);
    }
    final id = nextId++;
    final stored = goal.copyWith(id: id);
    _goals[id] = stored;
    lastCreated = stored;
    return id;
  }

  @override
  Future<int> update(Goal goal) async {
    if (delay > Duration.zero) {
      await Future<void>.delayed(delay);
    }
    if (goal.id == null) {
      throw StateError('update without id');
    }
    _goals[goal.id!] = goal;
    lastUpdated = goal;
    return goal.id!;
  }

  @override
  Future<void> delete(int id) async {
    if (delay > Duration.zero) {
      await Future<void>.delayed(delay);
    }
    _goals.remove(id);
  }
}
