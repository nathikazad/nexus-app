/// `threshold_op` / `target.op` as supported by [`_check_threshold`].
enum GoalThresholdOp { gte, gt, eq, lte, lt }

GoalThresholdOp goalThresholdOpFromKgql(String raw) {
  switch (raw) {
    case '>=':
      return GoalThresholdOp.gte;
    case '>':
      return GoalThresholdOp.gt;
    case '==':
      return GoalThresholdOp.eq;
    case '<=':
      return GoalThresholdOp.lte;
    case '<':
      return GoalThresholdOp.lt;
    default:
      throw FormatException('Unknown goal threshold op: $raw');
  }
}

String goalThresholdOpToKgql(GoalThresholdOp op) {
  switch (op) {
    case GoalThresholdOp.gte:
      return '>=';
    case GoalThresholdOp.gt:
      return '>';
    case GoalThresholdOp.eq:
      return '==';
    case GoalThresholdOp.lte:
      return '<=';
    case GoalThresholdOp.lt:
      return '<';
  }
}

/// Policy target in goal JSON responses ([`target`] block).
class GoalTarget {
  const GoalTarget({required this.op, required this.value});

  final GoalThresholdOp op;
  final num value;
}
