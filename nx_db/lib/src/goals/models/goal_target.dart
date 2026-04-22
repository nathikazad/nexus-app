import '../goal_parsing.dart';

/// `target: { "op", "value" }` from app goal responses (wire shape).
class GoalTarget {
  const GoalTarget({
    required this.op,
    required this.value,
  });

  final String op;
  final num value;

  factory GoalTarget.fromJson(Map<String, dynamic> json) {
    return GoalTarget(
      op: json['op'] as String? ?? '==',
      value: parseNumLoose(json['value']) ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {'op': op, 'value': value};
}
