import 'package:nx_time/domain/goals/action_goal.dart';
import 'package:nx_time/domain/goals/goal_cadence.dart';

/// Which reference layout to show in [GoalDetailPage] (see `reference/partials/page-goal-detail-*.html`).
enum GoalDetailVariant {
  /// Daily count + time-attribute threshold (wake before 7am, sleep by 11pm, …).
  wake,

  /// Daily sum / duration (sleep hours, reading time, …).
  sleep,

  /// Weekly count + optional slots (gym, …).
  gym,
}

/// Hard-coded mapping from domain goal to detail layout; replace with metadata later.
GoalDetailVariant goalDetailVariantFor(ActionGoalWeekItem item) {
  if (item.cadence == GoalCadence.weekly) {
    return GoalDetailVariant.gym;
  }
  if (item.aggregation == 'sum') {
    return GoalDetailVariant.sleep;
  }
  return GoalDetailVariant.wake;
}
